//
//  AccountDataService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Foundation


/// The default `AccountDataServiceProtocol`, built on `Client.accountData(eventType:)` and its
/// sibling setter, observer and room scoped observer.
final class AccountDataService: AccountDataServiceProtocol {

    private let clientService: any ClientServiceProtocol

    private let subscriptions = SubscriptionBag()

    private static let secretStorageKeyPrefix = "m.secret_storage.key."

    init(clientService: any ClientServiceProtocol) {
        self.clientService = clientService
    }

    func global(eventType: AccountDataEventType) async throws -> Data? {
        let client = try activeClient()
        let json: String?

        do {
            json = try await client.accountData(eventType: eventType.rawValue)
        } catch {
            throw AccountDataFailure.fetchFailed(SDKErrorInfo(error))
        }

        return json?.data(using: .utf8)
    }

    func setGlobal(
        eventType: AccountDataEventType,
        content  : some Encodable
    ) async throws {

        let client = try activeClient()
        let data: Data

        do {
            data = try JSONEncoder().encode(content)
        } catch {
            throw AccountDataFailure.encodingFailed(eventType: eventType.rawValue)
        }

        guard let json = String(data: data, encoding: .utf8) else {
            throw AccountDataFailure.encodingFailed(eventType: eventType.rawValue)
        }

        do {
            try await client.setAccountData(eventType: eventType.rawValue, content: json)
        } catch {
            throw AccountDataFailure.saveFailed(SDKErrorInfo(error))
        }
    }

    func observeGlobal(eventType: AccountDataEventType) throws -> AsyncStream<Data> {
        let client = try activeClient()

        guard let sdkType = Self.sdkGlobalType(for: eventType) else {
            throw AccountDataFailure.unobservable(eventType: eventType.rawValue)
        }

        let (changeStream, listener) = makeSDKStream(of: MatrixRustSDK.AccountDataEvent.self)

        subscriptions.retain(client.observeAccountDataEvent(eventType: sdkType, listener: listener))

        let (outputStream, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .unbounded)

        // The listener only ever signals "something changed"; refetching here is what turns that
        // signal into the actual new value, and it is also what supplies the very first one.
        subscriptions.retain(Task { [weak self] in
            if let initial = try? await self?.global(eventType: eventType) {
                continuation.yield(initial)
            }

            for await _ in changeStream {
                guard let data = try? await self?.global(eventType: eventType) else {
                    continue
                }

                continuation.yield(data)
            }

            continuation.finish()
        })

        return outputStream
    }

    func observeRoom(
        roomID   : String,
        eventType: AccountDataEventType
    ) throws -> AsyncStream<Data> {

        let client = try activeClient()

        guard let sdkType = Self.sdkRoomType(for: eventType) else {
            throw AccountDataFailure.unobservable(eventType: eventType.rawValue)
        }

        let (changeStream, listener) = makeSDKStream(of: SDKRoomAccountDataEvent.self)
        let subscription: TaskHandle

        do {
            subscription = try client.observeRoomAccountDataEvent(
                roomId   : roomID,
                eventType: sdkType,
                listener : listener
            )
        } catch {
            throw AccountDataFailure.roomUnavailable(SDKErrorInfo(error))
        }

        subscriptions.retain(subscription)

        let (outputStream, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .unbounded)

        // Unlike the global side there is no getter to refetch from, so the JSON the server would
        // have sent is rebuilt by hand from the already parsed event the listener handed back.
        subscriptions.retain(Task {
            for await update in changeStream where update.roomID == roomID {
                guard let data = try? Self.encodeRoomEvent(update.event) else {
                    continue
                }

                continuation.yield(data)
            }

            continuation.finish()
        })

        return outputStream
    }

    func shutdown() {
        subscriptions.cancelAll()
    }

    private func activeClient() throws -> Client {
        guard let client = clientService.sdkClient else {
            throw AccountDataFailure.noActiveClient
        }

        return client
    }

    /// Maps to the SDK's own closed set of global account data types, when `eventType` matches
    /// one of them; observing anything else is not something the SDK's listener API can do.
    private static func sdkGlobalType(for eventType: AccountDataEventType) -> MatrixRustSDK.AccountDataEventType? {
        switch eventType.rawValue {
            case AccountDataEventType.direct.rawValue: return .direct
            case AccountDataEventType.identityServer.rawValue: return .identityServer
            case AccountDataEventType.ignoredUserList.rawValue: return .ignoredUserList
            case AccountDataEventType.pushRules.rawValue: return .pushRules
            case AccountDataEventType.secretStorageDefaultKey.rawValue: return .secretStorageDefaultKey

            default:
                guard eventType.rawValue.hasPrefix(secretStorageKeyPrefix) else {
                    return nil
                }

                return .secretStorageKey(keyId: String(eventType.rawValue.dropFirst(secretStorageKeyPrefix.count)))
        }
    }

    /// Maps to the SDK's own closed set of room scoped account data types, when `eventType`
    /// matches one of them.
    private static func sdkRoomType(for eventType: AccountDataEventType) -> RoomAccountDataEventType? {
        switch eventType.rawValue {
            case AccountDataEventType.fullyRead.rawValue: return .fullyRead
            case AccountDataEventType.tag.rawValue: return .tag
            case AccountDataEventType.markedUnread.rawValue: return .markedUnread
            default: return nil
        }
    }

    /// Rebuilds the JSON the server would have sent for a room scoped account data event, since
    /// the SDK's listener hands back an already parsed enum rather than the raw payload.
    private static func encodeRoomEvent(_ event: RoomAccountDataEvent) throws -> Data {
        switch event {
            case .fullyReadEvent(let eventID):
                return try JSONEncoder().encode(["event_id": eventID])

            case .markedUnread(let unread), .unstableMarkedUnread(let unread):
                return try JSONEncoder().encode(["unread": unread])

            case .tag(let tags):
                var wireTags: [String: [String: Double?]] = [:]

                for (name, info) in tags {
                    wireTags[wireTagName(name)] = ["order": info.order]
                }

                return try JSONEncoder().encode(["tags": wireTags])
        }
    }

    private static func wireTagName(_ name: TagName) -> String {
        switch name {
            case .favorite: "m.favourite"
            case .lowPriority: "m.lowpriority"
            case .serverNotice: "m.server_notice"
            case .user(let userName): "u.\(userName.name)"
        }
    }
}
