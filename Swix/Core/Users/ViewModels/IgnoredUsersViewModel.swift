//
//  IgnoredUsersViewModel.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation


/// Everything an ignore list screen binds to: the current list, and what to say when a change
/// fails.
@Observable
final class IgnoredUsersViewModel {

    /// The failure to present. Views clear it by setting it back to nil.
    var failure: UserFacingFailure?

    @ObservationIgnored
    private let repository: IgnoredUsersRepository

    init(repository: IgnoredUsersRepository) {
        self.repository = repository
    }

    /// The ids of every user the account currently ignores.
    var ignoredUserIDs: [String] {
        repository.ignoredUserIDs
    }

    /// Whether an ignore or unignore call is in flight.
    var isBusy: Bool {
        repository.isBusy
    }

    /// Loads the current ignore list.
    func start() async {
        await repository.start()

        updateFailure()
    }

    /// Adds a user to the ignore list.
    func ignore(userID: String) async {
        await repository.ignore(userID: userID)

        updateFailure()
    }

    /// Removes a user from the ignore list.
    func unignore(userID: String) async {
        await repository.unignore(userID: userID)

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
