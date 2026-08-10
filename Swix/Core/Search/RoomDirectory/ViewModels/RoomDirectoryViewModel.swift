//
//  RoomDirectoryViewModel.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Observation


/// Everything the room directory screen binds to: the search field, the rooms, and what to say
/// when the homeserver refuses.
@Observable
final class RoomDirectoryViewModel {

    /// The failure to present. Views clear it by setting it back to nil.
    var failure: UserFacingFailure?

    @ObservationIgnored
    private let repository: RoomDirectoryRepository

    @ObservationIgnored
    private var searchTask: Task<Void, Never>?

    private var queryText = ""

    init(repository: RoomDirectoryRepository) {
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

    /// Rooms the directory returned for the query that is currently loaded.
    var rooms: [DirectoryRoom] {
        repository.rooms
    }

    /// Whether a spinner belongs on screen.
    var isLoading: Bool {
        repository.loadState.isLoading
    }

    /// Whether reaching the end of the list should ask for one more page.
    var canLoadMore: Bool {
        repository.loadState.canLoadMore
    }

    /// Whether the "no rooms" placeholder belongs on screen.
    var showsEmptyState: Bool {
        rooms.isEmpty && !isLoading && repository.loadState != .idle
    }

    /// Browses the directory when the screen opens, before the user has typed anything.
    func loadInitialResults() async {
        await runSearch(queryText)
    }

    /// Loads the next page. Called when the last row appears.
    func loadMore() async {
        await repository.loadMore()

        updateFailure()
    }

    /// Cancels the pending debounce, for a screen that is going away.
    func stop() {
        searchTask?.cancel()
        searchTask = nil

        failure = nil
    }

    /// Same debounce as the message search: long enough to collapse a word into one request, short
    /// enough that the list feels like it is following the keyboard.
    private static let debounceDelay = Duration.milliseconds(250)

    private func scheduleSearch() {
        searchTask?.cancel()

        let query = queryText

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
            case .paginationFailed: "Could not load more rooms"
            case .directoryFailed, .queryFailed, .userSearchFailed: "Could not reach the room directory"
        }
    }
}
