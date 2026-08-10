//
//  SyncRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation
import os


/// The single source of truth for whether sync is running, and the only writer of `SyncState`.
///
/// `start()`/`stop()` are the foreground/background toggle a `SyncLifecycleController` drives, not
/// a teardown: the observing task keeps running underneath so the state stream stays accurate even
/// while sync is paused. `shutdown()` is the actual teardown, called once when the session ends.
@Observable
final class SyncRepository {

    /// Where sync stands right now. Views observe this through a view model.
    private(set) var syncState: SyncState = .idle

    /// Whether the room list's "still syncing" indicator should be visible right now.
    private(set) var isShowingSyncIndicator = false

    /// The last failure `start()` raised, kept until the next attempt clears it.
    private(set) var failure: SyncFailure?

    @ObservationIgnored
    private let coordinator: any SyncCoordinatorProtocol

    @ObservationIgnored
    private let subscriptions = SubscriptionBag()

    @ObservationIgnored
    private var isObserving = false

    init(coordinator: any SyncCoordinatorProtocol) {
        self.coordinator = coordinator
    }

    /// Starts observing the coordinator's streams on first call, then starts or resumes sync.
    func start() async {
        observeCoordinatorIfNeeded()

        do {
            try await coordinator.start()

            failure = nil
        } catch {
            let syncFailure = error as? SyncFailure ?? .startFailed(SDKErrorInfo(error))

            Log.sync.error("Sync failed to start: \(String(reflecting: error), privacy: .public)")

            failure   = syncFailure
            syncState = .failed
        }
    }

    /// Pauses sync without releasing any subscription, so a later `start()` resumes instantly.
    func stop() async {
        await coordinator.stop()
    }

    /// Releases every subscription this repository and its coordinator own. Called once, by the
    /// scope that created them, when the session ends.
    func shutdown() {
        subscriptions.cancelAll()
        coordinator.shutdown()
    }

    private func observeCoordinatorIfNeeded() {
        guard !isObserving else {
            return
        }

        isObserving = true

        subscriptions.retain(Task { [weak self, stateStream = coordinator.stateStream] in
            for await state in stateStream {
                self?.syncState = state
            }
        })

        subscriptions.retain(Task { [weak self, indicatorStream = coordinator.indicatorStream] in
            for await indicator in indicatorStream {
                self?.isShowingSyncIndicator = indicator == .visible
            }
        })
    }
}
