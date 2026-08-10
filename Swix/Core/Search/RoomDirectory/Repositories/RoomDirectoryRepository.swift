//
//  RoomDirectoryRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Observation
import os


/// The single source of truth for the public room directory listing and its pagination.
@Observable
final class RoomDirectoryRepository {

    /// Rooms the directory returned for the current filter, in server order.
    private(set) var rooms: [DirectoryRoom] = []

    /// Where the current listing stands.
    private(set) var loadState: SearchLoadState = .idle

    /// The last failure, kept until the next attempt clears it.
    private(set) var failure: SearchFailure?

    @ObservationIgnored
    private let service: any RoomDirectorySearchServiceProtocol

    @ObservationIgnored
    private let subscriptions = SubscriptionBag()

    @ObservationIgnored
    private var isObserving = false

    @ObservationIgnored
    private var currentFilter: String?

    @ObservationIgnored
    private var hasSearched = false

    init(service: any RoomDirectorySearchServiceProtocol) {
        self.service = service
    }

    /// Runs a new directory listing. An empty query browses the whole directory, which is what the
    /// screen shows before the user types anything.
    func search(
        query        : String,
        viaServerName: String? = nil
    ) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filter = trimmedQuery.isEmpty ? nil : trimmedQuery

        guard filter != currentFilter || !hasSearched else {
            return
        }

        currentFilter = filter
        hasSearched = true

        observeServiceIfNeeded()

        rooms.removeAll()
        failure = nil
        loadState = .loading

        do {
            try await service.search(filter: filter, viaServerName: viaServerName)

            await updateLoadState()
        } catch {
            record(error)
        }
    }

    /// Asks the server for one more page. A no-op unless the last page said there is more.
    func loadMore() async {
        guard loadState.canLoadMore else {
            return
        }

        loadState = .loading

        do {
            try await service.loadNextPage()

            await updateLoadState()
        } catch {
            record(error)
        }
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
                self?.rooms.applyDiffs(diffs)
            }
        })
    }

    /// The directory has no pagination listener, so the end of the list is asked for explicitly
    /// after every page instead of being pushed at us.
    private func updateLoadState() async {
        do {
            let isAtLastPage = try await service.isAtLastPage()

            loadState = .loaded(hasMoreResults: !isAtLastPage)
        } catch {
            record(error)
        }
    }

    private func record(_ error: any Error) {
        let searchFailure = error as? SearchFailure ?? .directoryFailed(SDKErrorInfo(error))

        Log.search.error("Room directory search failed: \(String(reflecting: error), privacy: .public)")

        failure = searchFailure
        loadState = .loaded(hasMoreResults: false)
    }
}
