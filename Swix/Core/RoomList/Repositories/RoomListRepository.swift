//
//  RoomListRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation
import os


/// The single source of truth for the chat list, and the only writer of `rooms`.
///
/// The array is rebuilt exclusively by applying the service's diff batches in order, never by
/// refetching, so the list stays in step with the SDK's own ordering.
@Observable
final class RoomListRepository {

    /// Every room currently matching the active filter, in the order the SDK sorted them.
    private(set) var rooms: [RoomSummary] = []

    /// Whether the first page has arrived yet.
    private(set) var loadState: RoomListLoadState = .notLoaded

    /// The last failure, kept until the next attempt clears it.
    private(set) var failure: RoomListFailure?

    @ObservationIgnored
    private let entriesService: any RoomListEntriesServiceProtocol

    @ObservationIgnored
    private let subscriptions = SubscriptionBag()

    @ObservationIgnored
    private var visibleRoomsTask: Task<Void, Never>?

    @ObservationIgnored
    private var subscribedRoomIDs: Set<String> = []

    @ObservationIgnored
    private var isObserving = false

    init(entriesService: any RoomListEntriesServiceProtocol) {
        self.entriesService = entriesService
    }

    /// The rooms the user pinned, which the chat list renders in its own section.
    var favourites: [RoomSummary] {
        rooms.filter(\.isFavourite)
    }

    /// Everything else worth showing, with pinned and deprioritized rooms taken out.
    var others: [RoomSummary] {
        rooms.filter { !$0.isFavourite && !$0.isLowPriority }
    }

    /// Starts observing the entries service on first call, then builds the room list.
    func start() async {
        observeServiceIfNeeded()

        do {
            try await entriesService.start()

            failure = nil
        } catch {
            let listFailure = RoomListFailure.wrapping(error)

            Log.roomList.error("Room list failed to start: \(String(reflecting: error), privacy: .public)")

            failure = listFailure
        }
    }

    /// Narrows the list. The result arrives as an ordinary diff batch, so nothing is cleared here.
    func setFilter(_ filter: RoomListFilter) {
        entriesService.setFilter(filter)
    }

    /// Asks for one more page, for when the user scrolls past what has been loaded.
    func loadMore() {
        entriesService.loadMore()
    }

    /// Forwards the set of rooms currently on screen so the SDK keeps them fresh.
    ///
    /// Scrolling produces this call constantly, so an unchanged set is dropped and a superseded
    /// subscription is cancelled rather than piling up one task per visible row.
    func visibleRangeChanged(ids: [String]) {
        let requested = Set(ids)

        guard !requested.isEmpty, requested != subscribedRoomIDs else {
            return
        }

        subscribedRoomIDs = requested
        visibleRoomsTask?.cancel()
        visibleRoomsTask = Task { [weak self] in
            guard let self else {
                return
            }

            await entriesService.subscribeToVisibleRooms(ids: ids)
        }
    }

    /// Releases every subscription this repository and its service own. Called once, by the scope
    /// that created them, when the session ends.
    func shutdown() {
        visibleRoomsTask?.cancel()
        visibleRoomsTask  = nil
        subscribedRoomIDs = []

        subscriptions.cancelAll()
        entriesService.shutdown()

        isObserving = false
    }

    /// Wires the service's two streams into `rooms` and `loadState` exactly once, so a screen that
    /// appears more than once never stacks a second pair of observers.
    private func observeServiceIfNeeded() {
        guard !isObserving else {
            return
        }

        isObserving = true

        subscriptions.retain(Task { [weak self, diffs = entriesService.summaryDiffs()] in
            for await batch in diffs {
                self?.rooms.applyDiffs(batch)
            }
        })

        subscriptions.retain(Task { [weak self, states = entriesService.loadingStateStream()] in
            for await state in states {
                self?.loadState = state
            }
        })
    }
}
