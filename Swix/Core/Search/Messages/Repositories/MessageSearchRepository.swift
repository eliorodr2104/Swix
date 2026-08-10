//
//  MessageSearchRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Observation
import os


/// The single source of truth for the message search results and their pagination state.
@Observable
final class MessageSearchRepository {

    /// Matches for the current query, in the order the index ranked them.
    private(set) var results: [MessageSearchResult] = []

    /// Where the current query stands.
    private(set) var loadState: SearchLoadState = .idle

    /// The last failure, kept until the next attempt clears it.
    private(set) var failure: SearchFailure?

    @ObservationIgnored
    private let service: any MessageSearchServiceProtocol

    @ObservationIgnored
    private let subscriptions = SubscriptionBag()

    @ObservationIgnored
    private var isObserving = false

    @ObservationIgnored
    private var currentQuery = ""

    init(service: any MessageSearchServiceProtocol) {
        self.service = service
    }

    /// Runs a new query, or clears everything when the query is empty. Repeating the query that is
    /// already loaded does nothing, so a view model is free to call this on every keystroke.
    func search(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedQuery != currentQuery else {
            return
        }

        currentQuery = trimmedQuery

        guard !trimmedQuery.isEmpty else {
            clear()

            return
        }

        observeServiceIfNeeded()

        // The service also emits a reset for the new query, but dropping the previous matches here
        // keeps the list from showing answers to a question the user already moved on from.
        results.removeAll()
        failure = nil
        loadState = .loading

        do {
            try await service.setQuery(trimmedQuery)
        } catch {
            record(error)
        }
    }

    /// Asks the index for one more page. A no-op unless the last page said there is more.
    func loadMore() async {
        guard loadState.canLoadMore, !currentQuery.isEmpty else {
            return
        }

        do {
            try await service.paginate()
        } catch {
            record(error)
        }
    }

    /// Drops the current query and every match, without touching the subscriptions.
    func clear() {
        currentQuery = ""
        results.removeAll()
        failure = nil
        loadState = .idle
    }

    /// Releases every subscription this repository and its service own. Called once, by the scope
    /// that created them, when the session ends.
    func shutdown() {
        subscriptions.cancelAll()
        service.shutdown()
    }

    private func observeServiceIfNeeded() {
        guard !isObserving else {
            return
        }

        isObserving = true

        subscriptions.retain(Task { [weak self, resultDiffs = service.resultDiffs] in
            for await diffs in resultDiffs {
                self?.results.applyDiffs(diffs)
            }
        })

        subscriptions.retain(Task { [weak self, loadStates = service.loadStates] in
            for await state in loadStates {
                self?.loadState = state
            }
        })
    }

    private func record(_ error: any Error) {
        let searchFailure = error as? SearchFailure ?? .queryFailed(SDKErrorInfo(error))

        Log.search.error("Message search failed: \(String(reflecting: error), privacy: .public)")

        failure = searchFailure
        loadState = .loaded(hasMoreResults: false)
    }
}
