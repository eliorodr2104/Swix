//
//  LocationService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import MatrixRustSDK
import os


/// The default `LocationServiceProtocol`, built on the SDK's `Timeline.sendLocation`, `Room`'s
/// live location endpoints, and the client's own-beacon listener.
final class LocationService: LocationServiceProtocol {

    let ownBeaconUpdates: AsyncStream<OwnBeaconShareUpdate>

    private let clientService: any ClientServiceProtocol

    private let roomProvider: any RoomProviding

    private let timelineProvider: any TimelineProviderProtocol

    private let ownBeaconContinuation: AsyncStream<OwnBeaconShareUpdate>.Continuation

    private let subscriptions = SubscriptionBag()

    private var didStart = false

    // The listener is retained the same way EncryptionService retains its state listeners: the
    // TaskHandle in `subscriptions` keeps the Rust side subscription alive, this keeps the Swift
    // side adapter that feeds `ownBeaconUpdates` alive.
    private var ownBeaconListener: SDKListener<BeaconInfoUpdate>?

    // One live shares observer per open room, so a second `liveShares(forRoom:)` call for the same
    // room reuses the existing homeserver subscription instead of registering a duplicate one.
    private var roomObservations: [String: RoomObservation] = [:]

    init(
        clientService   : any ClientServiceProtocol,
        roomProvider    : any RoomProviding,
        timelineProvider: any TimelineProviderProtocol
    ) {

        self.clientService    = clientService
        self.roomProvider     = roomProvider
        self.timelineProvider = timelineProvider

        (ownBeaconUpdates, ownBeaconContinuation) = AsyncStream<OwnBeaconShareUpdate>.makeStream(bufferingPolicy: .unbounded)
    }

    func start() throws {
        guard !didStart else {
            return
        }

        guard let client = clientService.sdkClient else {
            throw LocationFailure.noActiveClient
        }

        let (updates, listener) = makeSDKStream(of: BeaconInfoUpdate.self)

        do {
            subscriptions.retain(try client.subscribeToOwnBeaconInfoUpdates(listener: listener))

        } catch { throw LocationFailure.actionFailed(SDKErrorInfo(error)) }

        ownBeaconListener = listener
        didStart = true

        subscriptions.retain(
            Task { [ownBeaconContinuation] in
                for await update in updates {
                    ownBeaconContinuation.yield(OwnBeaconMapper.makeUpdate(from: update))
                }
            }
        )
    }

    func sendStaticLocation(
        roomID : String,
        payload: LocationPayload
    ) async throws {

        do {
            let timeline = try await timelineProvider.liveTimeline(forRoom: roomID)

            try await timeline.sendLocation(
                body       : LocationPayloadMapper.makeBody(from: payload),
                geoUri     : payload.geoUri,
                description: payload.description,
                zoomLevel  : payload.zoomLevel
            )

        } catch let failure as TimelineFailure {
            throw Self.locationFailure(from: failure)

        } catch { throw LocationFailure.sendFailed(SDKErrorInfo(error)) }
    }

    @discardableResult
    func startLiveShare(
        roomID  : String,
        duration: TimeInterval
    ) async throws -> String {

        let room = try activeRoom(roomID)

        do {
            return try await room.startLiveLocationShare(durationMillis: UInt64((duration * 1000).rounded()))

        } catch { throw LocationFailure.shareFailed(SDKErrorInfo(error)) }
    }

    func updateLiveShare(
        roomID : String,
        payload: LocationPayload
    ) async throws {

        let room = try activeRoom(roomID)

        do {
            try await room.sendLiveLocation(geoUri: payload.geoUri)

        } catch { throw LocationFailure.sendFailed(SDKErrorInfo(error)) }
    }

    func stopLiveShare(roomID: String) async throws {
        let room = try activeRoom(roomID)

        do {
            try await room.stopLiveLocationShare()

        } catch { throw LocationFailure.shareFailed(SDKErrorInfo(error)) }
    }

    func liveShares(forRoom roomID: String) async throws -> AsyncStream<[CollectionDiff<LiveLocationShare>]> {
        if let observation = roomObservations[roomID] {
            return observation.diffs
        }

        let room = try activeRoom(roomID)
        let observer = await room.liveLocationsObserver()
        let (updates, listener) = makeSDKStream(of: [LiveLocationShareUpdate].self)
        let (diffs, continuation) = AsyncStream<[CollectionDiff<LiveLocationShare>]>.makeStream(bufferingPolicy: .unbounded)
        let bag = SubscriptionBag()

        bag.retain(observer.subscribe(listener: listener))
        bag.retain(
            Task { [continuation] in
                for await batch in updates {
                    continuation.yield(LiveLocationShareMapper.makeDiffs(from: batch))
                }
            }
        )

        roomObservations[roomID] = RoomObservation(
            observer     : observer,
            subscriptions: bag,
            diffs        : diffs
        )

        Log.location.notice("Live locations observed for room \(roomID, privacy: .private)")

        return diffs
    }

    func tileServer() async -> TileServerInfo? {
        guard let client = clientService.sdkClient else {
            return nil
        }

        return TileServerInfoMapper.makeTileServerInfo(from: await client.tileServer())
    }

    func release(roomID: String) {
        roomObservations[roomID]?.subscriptions.cancelAll()
        roomObservations[roomID] = nil
    }

    func shutdown() {
        subscriptions.cancelAll()

        ownBeaconListener = nil
        didStart = false

        roomObservations.values.forEach { $0.subscriptions.cancelAll() }
        roomObservations.removeAll()
    }

    /// `RoomProviding` fails with our own `SyncFailure` only when sync never ran, which is worth
    /// telling apart from a room the list genuinely does not have.
    private func activeRoom(_ roomID: String) throws -> Room {
        do {
            return try roomProvider.room(withId: roomID)

        } catch is SyncFailure {
            throw LocationFailure.notStarted

        } catch { throw LocationFailure.roomUnavailable(SDKErrorInfo(error)) }
    }

    /// A one-shot send borrows the Timeline feature's own service instead of opening a second
    /// timeline, so its failures arrive as a `TimelineFailure` that has to be translated rather
    /// than falling through to a generic, less useful message.
    private static func locationFailure(from timelineFailure: TimelineFailure) -> LocationFailure {
        switch timelineFailure {
            case .notStarted: .notStarted
            case .noActiveClient: .noActiveClient
            case .roomUnavailable(let info), .timelineUnavailable(let info): .roomUnavailable(info)
            case .sendFailed(let info), .paginationFailed(let info), .actionFailed(let info): .sendFailed(info)
        }
    }

    /// Keeps one room's live share observer alongside the subscriptions it needs, so
    /// `release(roomID:)` can tear both down together instead of hunting through parallel maps.
    ///
    /// The observer itself must be retained, not just its `TaskHandle`: `LiveLocationsObserver`
    /// keeps the SDK's beacon event handlers registered only for as long as the object is alive.
    private struct RoomObservation {
        let observer: LiveLocationsObserver
        let subscriptions: SubscriptionBag
        let diffs: AsyncStream<[CollectionDiff<LiveLocationShare>]>
    }
}
