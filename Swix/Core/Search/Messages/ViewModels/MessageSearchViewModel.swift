//
//  MessageSearchViewModel.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Observation


/// Everything the message search screen binds to: the search field, the matches, and what to say
/// when the index refuses a query.
@Observable
final class MessageSearchViewModel {

    /// The failure to present. Views clear it by setting it back to nil.
    var failure: UserFacingFailure?

    @ObservationIgnored
    private let repository: MessageSearchRepository

    @ObservationIgnored
    private var searchTask: Task<Void, Never>?

    private var queryText = ""

    init(repository: MessageSearchRepository) {
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

    /// Matches for the query that is currently loaded.
    var results: [MessageSearchResult] {
        repository.results
    }

    /// Whether a spinner belongs on screen.
    var isSearching: Bool {
        repository.loadState.isLoading
    }

    /// Whether reaching the end of the list should ask for one more page.
    var canLoadMore: Bool {
        repository.loadState.canLoadMore
    }

    /// Whether the "no results" placeholder belongs on screen.
    var showsEmptyState: Bool {
        results.isEmpty && !isSearching && repository.loadState != .idle
    }

    /// Loads the next page. Called when the last row appears.
    func loadMore() async {
        await repository.loadMore()

        updateFailure()
    }

    /// Cancels the pending debounce and drops the query, for a screen that is going away.
    func stop() {
        searchTask?.cancel()
        searchTask = nil

        repository.clear()

        queryText = ""
        failure = nil
    }

    /// A query is only worth sending once the user pauses; 250ms is short enough to feel instant
    /// and long enough to collapse a whole word into a single index lookup.
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
            case .queryFailed: "Search failed"
            case .paginationFailed: "Could not load more results"
            case .directoryFailed, .userSearchFailed: "Something went wrong"
        }
    }
}
