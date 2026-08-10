//
//  UserSearchViewModel.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Observation


/// Everything a "start a chat" screen binds to: the search field, the users, and what to say when
/// the directory refuses.
@Observable
final class UserSearchViewModel {

    /// The failure to present. Views clear it by setting it back to nil.
    var failure: UserFacingFailure?

    @ObservationIgnored
    private let repository: UserSearchRepository

    @ObservationIgnored
    private var searchTask: Task<Void, Never>?

    private var queryText = ""

    init(repository: UserSearchRepository) {
        self.repository = repository
    }

    /// Bound to the search field. Every write restarts the debounce window instead of querying,
    /// which is why this is a computed property: `@Observable` does not track `didSet`.
    var query: String {
        get {
            queryText
        }
        set {
            queryText = newValue
            scheduleSearch()
        }
    }

    /// Users the directory returned for the query that is currently loaded.
    var users: [FoundUser] {
        repository.users
    }

    /// Whether a spinner belongs on screen.
    var isSearching: Bool {
        repository.loadState.isLoading
    }

    /// Whether the "no users" placeholder belongs on screen.
    var showsEmptyState: Bool {
        users.isEmpty && !isSearching && repository.loadState != .idle
    }

    /// Cancels the pending debounce and drops the query, for a screen that is going away.
    func stop() {
        searchTask?.cancel()
        searchTask = nil

        repository.clear()

        queryText = ""
        failure = nil
    }

    /// Same debounce as the other two searches, so every search field in the app reacts alike.
    private static let debounceDelay = Duration.milliseconds(250)

    private func scheduleSearch() {
        searchTask?.cancel()

        let query = queryText

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchTask = nil

            repository.clear()

            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounceDelay)

            guard !Task.isCancelled else {
                return
            }

            await self?.runSearch(query)
        }
    }

    private func runSearch(_ query: String) async {
        await repository.search(query: query)

        updateFailure()
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

    private static func title(for failure: SearchFailure) -> String {
        switch failure {
            case .noActiveClient: "You are not signed in"
            case .userSearchFailed, .queryFailed, .paginationFailed, .directoryFailed: "Could not search for people"
        }
    }
}
