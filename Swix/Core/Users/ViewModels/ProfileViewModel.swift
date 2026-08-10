//
//  ProfileViewModel.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Observation


/// Everything a profile screen binds to: the editable display name field, the current profile,
/// and what to say when a change fails.
@Observable
final class ProfileViewModel {

    /// Bound to the display name field. Seeded from the loaded profile in `start()`.
    var displayNameText = ""

    /// The failure to present. Views clear it by setting it back to nil.
    var failure: UserFacingFailure?

    @ObservationIgnored
    private let repository: OwnProfileRepository

    init(repository: OwnProfileRepository) {
        self.repository = repository
    }

    /// The signed in user's own profile, or nil before the first `start()` completes.
    var profile: UserProfileInfo? {
        repository.profile
    }

    /// Whether a change is in flight, which is what disables the form.
    var isBusy: Bool {
        repository.isBusy
    }

    /// Loads the profile and seeds the editable fields from it.
    func start() async {
        await repository.start()

        displayNameText = repository.profile?.displayName ?? ""

        updateFailure()
    }

    /// Submits the display name field, ignoring an attempt to save an empty name.
    func saveDisplayName() async {
        let trimmedName = displayNameText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            return
        }

        await repository.updateDisplayName(trimmedName)

        updateFailure()
    }

    /// Uploads and sets a new avatar.
    func updateAvatar(data: Data, mimeType: String) async {
        await repository.updateAvatar(data: data, mimeType: mimeType)

        updateFailure()
    }

    /// Removes the current avatar.
    func removeAvatar() async {
        await repository.removeAvatar()

        updateFailure()
    }

    /// Releases the repository's subscriptions. Called once, when the screen goes away for good.
    func shutdown() {
        repository.shutdown()
    }

    private func updateFailure() {
        guard let failure = repository.failure else {
            self.failure = nil

            return
        }

        self.failure = UserFacingFailure(
            title      : Self.title(for: failure),
            message    : failure.message,
            isRetryable: failure.isRetryable
        )
    }

    private static func title(for failure: UsersFailure) -> String {
        switch failure {
            case .noActiveClient: "No signed in account"
            case .sdk: "Something went wrong"
        }
    }
}
