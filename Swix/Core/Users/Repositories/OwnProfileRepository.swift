//
//  OwnProfileRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Observation


/// The single source of truth for the signed in user's own profile.
///
/// `start()` both loads the current profile and, on first call, wires the SDK subscription that
/// keeps it fresh; `shutdown()` is the teardown, releasing that subscription for good.
@Observable
final class OwnProfileRepository {

    /// The signed in user's own profile, refreshed whenever the homeserver reports a change.
    private(set) var profile: UserProfileInfo?

    /// Whether a display name or avatar change is in flight.
    private(set) var isBusy = false

    /// The last failure, cleared when a new attempt starts.
    private(set) var failure: UsersFailure?

    @ObservationIgnored
    private let profileService: any ProfileServiceProtocol

    @ObservationIgnored
    private let subscriptions = SubscriptionBag()

    @ObservationIgnored
    private var isObserving = false

    init(profileService: any ProfileServiceProtocol) {
        self.profileService = profileService
    }

    /// Starts observing own-profile updates on first call, then loads the current profile.
    func start() async {
        observeOwnProfileIfNeeded()

        do {
            profile = try await profileService.fetchOwnProfile()
            failure = nil
        } catch {
            record(error)
        }
    }

    /// Changes the display name and waits for the SDK to confirm it.
    func updateDisplayName(_ name: String) async {
        await perform {
            try await self.profileService.setDisplayName(name)
        }
    }

    /// Uploads new avatar bytes and sets the result as the current avatar.
    func updateAvatar(data: Data, mimeType: String) async {
        await perform {
            try await self.profileService.uploadAvatar(data: data, mimeType: mimeType)
        }
    }

    /// Removes the current avatar.
    func removeAvatar() async {
        await perform {
            try await self.profileService.removeAvatar()
        }
    }

    /// Releases every subscription this repository and its service own. Called once, by the scope
    /// that created them, when the session ends.
    func shutdown() {
        subscriptions.cancelAll()
        profileService.shutdown()
    }

    /// Wires the SDK own-profile subscription exactly once, forwarding every update into
    /// `profile`.
    private func observeOwnProfileIfNeeded() {
        guard !isObserving else {
            return
        }

        do {
            try profileService.startObservingOwnProfile()
        } catch {
            record(error)

            return
        }

        isObserving = true

        subscriptions.retain(Task { [weak self, stream = profileService.ownProfileStream] in
            for await profile in stream {
                self?.profile = profile
            }
        })
    }

    /// Shared busy/failure bookkeeping around a profile change.
    private func perform(_ operation: () async throws -> Void) async {
        isBusy = true
        failure = nil

        do {
            try await operation()
        } catch {
            record(error)
        }

        isBusy = false
    }

    private func record(_ error: any Error) {
        failure = UsersFailure.wrapping(error)
    }
}
