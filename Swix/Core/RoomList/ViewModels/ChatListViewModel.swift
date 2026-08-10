//
//  ChatListViewModel.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Observation


/// Everything the chat list screen binds to: its two sections, the search field, and what to say
/// when an action fails.
@Observable
final class ChatListViewModel {

    /// The failure to present. Views clear it by setting it back to nil.
    var failure: UserFacingFailure?

    @ObservationIgnored
    private let repository: RoomListRepository

    @ObservationIgnored
    private let actionsService: any RoomActionsServiceProtocol

    @ObservationIgnored
    private let syncRepository: SyncRepository?

    @ObservationIgnored
    private let searchDebounce: Duration

    @ObservationIgnored
    private var storedSearchQuery = ""

    @ObservationIgnored
    private var searchTask: Task<Void, Never>?

    @ObservationIgnored
    private var visibleRoomIDs: [String] = []

    init(
        repository    : RoomListRepository,
        actionsService: any RoomActionsServiceProtocol,
        syncRepository: SyncRepository? = nil,
        searchDebounce: Duration = .milliseconds(300)
    ) {
        self.repository     = repository
        self.actionsService = actionsService
        self.syncRepository = syncRepository
        self.searchDebounce = searchDebounce
    }

    /// Bound to the search field.
    ///
    /// The accessors are written by hand so the setter can debounce: the observation macro only
    /// generates them for plain stored properties, and a property observer would be dropped.
    var searchQuery: String {
        get {
            access(keyPath: \.searchQuery)

            return storedSearchQuery
        }
        set {
            guard newValue != storedSearchQuery else {
                return
            }

            withMutation(keyPath: \.searchQuery) {
                storedSearchQuery = newValue
            }

            scheduleSearch()
        }
    }

    /// The Pinned section, in the order the SDK sorted the list.
    var pinned: [RoomSummary] {
        repository.favourites
    }

    /// The Chats section, everything not pinned and not deprioritized.
    var chats: [RoomSummary] {
        repository.others
    }

    /// Whether the sync engine is still catching up, for the header's activity indicator.
    var isSyncing: Bool {
        syncRepository?.isShowingSyncIndicator ?? false
    }

    /// Whether the list has nothing to show yet and should render its loading state.
    var isLoading: Bool {
        !repository.loadState.isLoaded
    }

    /// Whether the account genuinely has no rooms matching the current filter.
    var isEmpty: Bool {
        repository.loadState.isLoaded && repository.rooms.isEmpty
    }

    /// Builds the list. Called when the screen appears for the first time.
    func start() async {
        await repository.start()

        updateFailure()
    }

    /// Pins or unpins a room, moving it between the two sections.
    func toggleFavourite(roomID: String) async {
        guard let summary = repository.rooms.first(where: { $0.id == roomID }) else {
            return
        }

        await run {
            try await actionsService.setFavourite(!summary.isFavourite, roomID: roomID)
        }
    }

    /// Clears a room's unread state, both its counters and its manual flag.
    func markAsRead(roomID: String) async {
        await run {
            try await actionsService.markAsRead(roomID: roomID)
            try await actionsService.setUnreadFlag(false, roomID: roomID)
        }
    }

    /// Records that the user opened a room, so it shows up in the recently visited list.
    func trackVisit(roomID: String) async {
        await run {
            try await actionsService.trackRecentlyVisited(roomID: roomID)
        }
    }

    /// Asks for one more page, for when the user scrolls past what has been loaded.
    func loadMore() {
        repository.loadMore()
    }

    /// Records that a row came on screen and forwards the current window to the repository.
    ///
    /// Only the most recent ids are kept: the server wants to know what the user is looking at,
    /// not everything they have ever scrolled past.
    func onAppear(of summary: RoomSummary) {
        visibleRoomIDs.removeAll { $0 == summary.id }
        visibleRoomIDs.append(summary.id)

        if visibleRoomIDs.count > Self.visibleRoomsWindow {
            visibleRoomIDs.removeFirst(visibleRoomIDs.count - Self.visibleRoomsWindow)
        }

        repository.visibleRangeChanged(ids: visibleRoomIDs)
    }

    /// Tears the list down when the session ends.
    func shutdown() {
        searchTask?.cancel()
        searchTask = nil
        visibleRoomIDs = []

        repository.shutdown()
    }

    private static let visibleRoomsWindow = 40

    /// Restarts the debounce timer on every keystroke, so the repository only ever sees the query
    /// the user has actually stopped typing on.
    private func scheduleSearch() {
        searchTask?.cancel()

        let query = storedSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        searchTask = Task { [weak self, searchDebounce] in
            try? await Task.sleep(for: searchDebounce)

            guard !Task.isCancelled else {
                return
            }

            self?.repository.setFilter(query.isEmpty ? .all : .search(query))
        }
    }

    /// Runs one action and turns any failure into the `UserFacingFailure` the view presents,
    /// clearing whatever was showing before when the action actually succeeds.
    private func run(_ action: () async throws -> Void) async {
        do {
            try await action()

            failure = nil
        } catch {
            failure = Self.makeUserFacingFailure(from: RoomListFailure.wrapping(error))
        }
    }

    /// Mirrors the repository's own failure onto this view model, which is what lets a load
    /// failure from `start()` reach the view the same way an action failure does.
    private func updateFailure() {
        guard let listFailure = repository.failure else {
            failure = nil

            return
        }

        failure = Self.makeUserFacingFailure(from: listFailure)
    }

    /// Builds the message a view actually shows, pairing a short title chosen by the failure case
    /// with the longer explanation the failure itself already carries.
    private static func makeUserFacingFailure(from failure: RoomListFailure) -> UserFacingFailure {
        UserFacingFailure(
            title      : title(for: failure),
            message    : failure.message,
            isRetryable: failure.isRetryable
        )
    }

    /// Picks the headline for each failure case; the fuller explanation lives in `failure.message`,
    /// kept separate because a view wants a short title and a longer body.
    private static func title(for failure: RoomListFailure) -> String {
        switch failure {
            case .notStarted: "Your chats are not ready yet"
            case .listUnavailable: "Could not load your chats"
            case .roomUnavailable: "That chat is gone"
            case .actionFailed: "Something went wrong"
            case .noActiveClient: "You are signed out"
        }
    }
}
