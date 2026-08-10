//
//  NotificationItemService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import os


/// The default `NotificationItemServiceProtocol`, built on `Client.notificationClient(processSetup:)`.
final class NotificationItemService: NotificationItemServiceProtocol {

    let syncNotifications: AsyncStream<NotificationItem>

    private let clientService: any ClientServiceProtocol

    private let syncServiceProvider: (any NotificationSyncServiceProviding)?

    private let notificationContinuation: AsyncStream<NotificationItem>.Continuation

    private let subscriptions = SubscriptionBag()

    private var notificationClient: NotificationClient?

    // `registerNotificationHandler` returns no TaskHandle, so this reference is the only thing
    // keeping the sync bridge alive.
    private var syncListener: SDKListener<SDKSyncNotification>?

    init(
        clientService      : any ClientServiceProtocol,
        syncServiceProvider: (any NotificationSyncServiceProviding)? = nil
    ) {
        self.clientService = clientService
        self.syncServiceProvider = syncServiceProvider

        (syncNotifications, notificationContinuation) = AsyncStream<NotificationItem>.makeStream(bufferingPolicy: .unbounded)
    }

    func startObservingSyncNotifications() async throws {
        guard syncListener == nil else {
            return
        }

        guard let client = clientService.sdkClient else {
            throw NotificationsFailure.noActiveClient
        }

        let (stream, listener) = makeSDKStream(of: SDKSyncNotification.self)

        syncListener = listener

        subscriptions.retain(Task { [notificationContinuation] in
            for await notification in stream {
                let item = NotificationItemMapper.makeNotificationItem(
                    from  : notification.notification,
                    roomID: notification.roomID
                )

                notificationContinuation.yield(item)
            }
        })

        await client.registerNotificationHandler(listener: listener)
    }

    func notification(
        roomID : String,
        eventID: String
    ) async throws -> NotificationItem? {
        let client = try await activeNotificationClient()

        do {
            let status = try await client.getNotification(roomId: roomID, eventId: eventID)

            return NotificationItemMapper.makeNotificationItem(
                from   : status,
                roomID : roomID,
                eventID: eventID
            )
        } catch {
            throw NotificationsFailure.sdk(SDKErrorInfo(error))
        }
    }

    func notifications(eventIDsByRoomID: [String: [String]]) async throws -> [String: NotificationItem] {
        let client = try await activeNotificationClient()

        let requests = eventIDsByRoomID.map { NotificationItemsRequest(roomId: $0.key, eventIds: $0.value) }

        // The batch result is keyed by event ID alone, so the room each event came from has to be
        // remembered here to be able to map the items back.
        var roomIDsByEventID: [String: String] = [:]

        for request in requests {
            for eventID in request.eventIds {
                roomIDsByEventID[eventID] = request.roomId
            }
        }

        let results: [String: BatchNotificationResult]

        do {
            results = try await client.getNotifications(requests: requests)
        } catch {
            throw NotificationsFailure.sdk(SDKErrorInfo(error))
        }

        var items: [String: NotificationItem] = [:]

        for (eventID, result) in results {
            guard let roomID = roomIDsByEventID[eventID] else {
                continue
            }

            switch result {
                case .ok(let status):
                    let item = NotificationItemMapper.makeNotificationItem(
                        from   : status,
                        roomID : roomID,
                        eventID: eventID
                    )

                    if let item {
                        items[eventID] = item
                    }

                case .error(let message):
                    Log.notifications.error("Notification \(eventID, privacy: .public) could not be fetched: \(message, privacy: .public)")
            }
        }

        return items
    }

    func shutdown() {
        subscriptions.cancelAll()

        syncListener = nil
        notificationClient = nil
    }

    /// Builds the notification client once. It runs its own short lived sliding sync, so rebuilding
    /// it per notification would pay for a fresh sync loop on every single push.
    private func activeNotificationClient() async throws -> NotificationClient {
        if let notificationClient {
            return notificationClient
        }

        guard let client = clientService.sdkClient else {
            throw NotificationsFailure.noActiveClient
        }

        do {
            let notificationClient = try await client.notificationClient(processSetup: makeProcessSetup())

            self.notificationClient = notificationClient

            return notificationClient
        } catch {
            throw NotificationsFailure.notificationClientUnavailable(SDKErrorInfo(error))
        }
    }

    /// Sharing the running sync service is both faster and safer than taking the cross process
    /// lock, so it is used whenever this process happens to own one.
    private func makeProcessSetup() -> NotificationProcessSetup {
        guard let syncService = syncServiceProvider?.activeSyncService() else {
            return .multipleProcesses
        }

        return .singleProcess(syncService: syncService)
    }
}
