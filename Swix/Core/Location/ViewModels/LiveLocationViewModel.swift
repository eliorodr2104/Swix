//
//  LiveLocationViewModel.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Observation


/// Everything a room's live location screen binds to: who is sharing, the account's own toggle,
/// and what to say when an action fails.
@Observable
final class LiveLocationViewModel {

    /// The failure to present. Views clear it by setting it back to nil.
    var failure: UserFacingFailure?

    @ObservationIgnored
    private let repository: LiveLocationRepository

    init(repository: LiveLocationRepository) {
        self.repository = repository
    }

    /// The room this screen is showing shares for.
    var roomID: String {
        repository.roomID
    }

    /// Every account currently sharing, for the map's pins.
    var activeShares: [LiveLocationShare] {
        repository.activeShares
    }

    /// Whether the account itself has an active share in this room, for the share toggle's state.
    var isSharingOwn: Bool {
        repository.isSharingOwn
    }

    /// Whether nobody, self included, is currently sharing.
    var isEmpty: Bool {
        activeShares.isEmpty
    }

    /// Starts observing this room's shares. Called when the screen appears.
    func start() async {
        await repository.start()

        updateFailure()
    }

    /// Sends the given position as a one-shot pin, not a live share.
    func sendStaticLocation(_ payload: LocationPayload) async {
        await repository.sendStaticLocation(payload)

        updateFailure()
    }

    /// Starts sharing the account's own location for `duration`.
    func startSharing(duration: TimeInterval) async {
        await repository.startLiveShare(duration: duration)

        updateFailure()
    }

    /// Pushes the account's current position into its own share already in progress.
    func updateSharedPosition(_ payload: LocationPayload) async {
        await repository.updateLiveShare(payload)

        updateFailure()
    }

    /// Stops the account's own share before its deadline would have.
    func stopSharing() async {
        await repository.stopLiveShare()

        updateFailure()
    }

    /// Tears the screen down when it goes away.
    func shutdown() {
        repository.shutdown()
    }

    private func updateFailure() {
        guard let locationFailure = repository.failure else {
            failure = nil

            return
        }

        failure = UserFacingFailure(
            title      : Self.title(for: locationFailure),
            message    : locationFailure.message,
            isRetryable: locationFailure.isRetryable
        )
    }

    private static func title(for failure: LocationFailure) -> String {
        switch failure {
            case .notStarted: "Location sharing is not ready yet"
            case .roomUnavailable: "That conversation is gone"
            case .sendFailed: "Your location did not go out"
            case .shareFailed: "Could not update live sharing"
            case .actionFailed: "Something went wrong"
            case .noActiveClient: "You are signed out"
        }
    }
}
