//
//  SyncCoordinator.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import os


/// The default `SyncCoordinatorProtocol`, built on `Client.syncService()`.
final class SyncCoordinator: SyncCoordinatorProtocol {

    let stateStream: AsyncStream<SyncState>

    let indicatorStream: AsyncStream<SyncIndicatorState>

    private let clientService: any ClientServiceProtocol

    private let stateContinuation: AsyncStream<SyncState>.Continuation

    private let indicatorContinuation: AsyncStream<SyncIndicatorState>.Continuation

    private let subscriptions = SubscriptionBag()

    private var syncService: SyncService?

    init(clientService: any ClientServiceProtocol) {
        self.clientService = clientService

        (stateStream, stateContinuation) = AsyncStream<SyncState>.makeStream(bufferingPolicy: .unbounded)
        (indicatorStream, indicatorContinuation) = AsyncStream<SyncIndicatorState>.makeStream(bufferingPolicy: .unbounded)
    }

    func start() async throws {
        let service = try await activeSyncService()

        await service.start()
    }

    func stop() async {
        await syncService?.stop()
    }

    func roomListService() throws -> RoomListService {
        guard let syncService else {
            throw SyncFailure.notStarted
        }

        return syncService.roomListService()
    }

    func room(withId roomID: String) throws -> Room {
        try roomListService().room(roomId: roomID)
    }

    func shutdown() {
        subscriptions.cancelAll()
        syncService = nil
    }

    /// Builds the SDK sync service exactly once and wires its observers, reusing it on every
    /// later call: rebuilding on every foreground transition would drop and re-register every
    /// listener for no benefit, since the SDK service itself supports being paused and resumed.
    private func activeSyncService() async throws -> SyncService {
        if let syncService {
            return syncService
        }

        guard let client = clientService.sdkClient else {
            throw SyncFailure.noActiveClient
        }

        do {
            let service = try await client.syncService().finish()

            syncService = service
            observe(service)

            return service
        } catch {
            throw SyncFailure.startFailed(SDKErrorInfo(error))
        }
    }

    private func observe(_ service: SyncService) {
        let (rawStateStream, stateListener) = makeSDKStream(of: SyncServiceState.self)

        subscriptions.retain(service.state(listener: stateListener))
        subscriptions.retain(Task { [stateContinuation] in
            for await state in rawStateStream {
                stateContinuation.yield(SyncStateMapper.makeSyncState(from: state))
            }
        })

        let roomListService = service.roomListService()
        let (rawIndicatorStream, indicatorListener) = makeSDKStream(of: RoomListServiceSyncIndicator.self)

        subscriptions.retain(
            roomListService.syncIndicator(
                delayBeforeShowingInMs: 1000,
                delayBeforeHidingInMs : 500,
                listener              : indicatorListener
            )
        )

        subscriptions.retain(Task { [indicatorContinuation] in
            for await indicator in rawIndicatorStream {
                indicatorContinuation.yield(SyncStateMapper.makeSyncIndicatorState(from: indicator))
            }
        })
    }
}
