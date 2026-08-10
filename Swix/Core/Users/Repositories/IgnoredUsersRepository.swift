//
//  IgnoredUsersRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation


/// The single source of truth for the signed in user's ignore list.
///
/// `start()` both loads the current list and, on first call, wires the SDK subscription that keeps
/// it fresh; `shutdown()` is the teardown, releasing that subscription for good.
@Observable
final class IgnoredUsersRepository {

    /// The ids of every user the account currently ignores.
    private(set) var ignoredUserIDs: [String] = []

    /// Whether an ignore or unignore call is in flight.
    private(set) var isBusy = false

    /// The last failure, cleared when a new attempt starts.
    private(set) var failure: UsersFailure?

    @ObservationIgnored
    private let ignoredUsersService: any IgnoredUsersServiceProtocol

    @ObservationIgnored
    private let subscriptions = SubscriptionBag()

    @ObservationIgnored
    private var isObserving = false

    init(ignoredUsersService: any IgnoredUsersServiceProtocol) {
        self.ignoredUsersService = ignoredUsersService
    }

    /// Starts observing ignore list updates on first call, then loads the current list.
    func start() async {
        observeIgnoredUsersIfNeeded()

        do {
            ignoredUserIDs = try await ignoredUsersService.fetchIgnoredUserIDs()
            failure = nil
        } catch {
            record(error)
        }
    }

    /// Adds a user to the ignore list. `ignoredUserIDs` updates once the homeserver confirms it.
    func ignore(userID: String) async {
        await perform {
            try await self.ignoredUsersService.ignore(userID: userID)
        }
    }

    /// Removes a user from the ignore list. `ignoredUserIDs` updates once the homeserver confirms
    /// it.
    func unignore(userID: String) async {
        await perform {
            try await self.ignoredUsersService.unignore(userID: userID)
        }
    }

    /// Releases every subscription this repository and its service own. Called once, by the scope
    /// that created them, when the session ends.
    func shutdown() {
        subscriptions.cancelAll()
        ignoredUsersService.shutdown()
    }

    /// Wires the SDK ignore list subscription exactly once, forwarding every update into
    /// `ignoredUserIDs`.
    private func observeIgnoredUsersIfNeeded() {
        guard !isObserving else {
            return
        }

        do {
            try ignoredUsersService.startObservingIgnoredUsers()
        } catch {
            record(error)

            return
        }

        isObserving = true

        subscriptions.retain(Task { [weak self, stream = ignoredUsersService.ignoredUserIDsStream] in
            for await ids in stream {
                self?.ignoredUserIDs = ids
            }
        })
    }

    /// Shared busy/failure bookkeeping around an ignore or unignore call.
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
