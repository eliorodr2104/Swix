//
//  MockRoomListEntriesService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

@testable import Swix


/// A `RoomListEntriesServiceProtocol` double that records every call and lets a test push diff
/// batches and load states through its two streams on demand.
final class MockRoomListEntriesService: RoomListEntriesServiceProtocol {

    /// How many times `start()` was called.
    private(set) var startCallCount = 0

    /// How many times `loadMore()` was called.
    private(set) var loadMoreCallCount = 0

    /// How many times `shutdown()` was called.
    private(set) var shutdownCallCount = 0

    /// Every filter `setFilter(_:)` was asked to apply, oldest first.
    private(set) var appliedFilters: [RoomListFilter] = []

    /// Every id list `subscribeToVisibleRooms(ids:)` was asked to subscribe, oldest first.
    private(set) var subscribedVisibleRoomIDs: [[String]] = []

    /// What `start()` throws next time it is called, nil for a plain success.
    var startError: (any Error)?

    private let diffStream: AsyncStream<[CollectionDiff<RoomSummary>]>

    private let diffContinuation: AsyncStream<[CollectionDiff<RoomSummary>]>.Continuation

    private let loadStateStreamValue: AsyncStream<RoomListLoadState>

    private let loadStateContinuation: AsyncStream<RoomListLoadState>.Continuation

    init() {
        (diffStream, diffContinuation) = AsyncStream<[CollectionDiff<RoomSummary>]>.makeStream(bufferingPolicy: .unbounded)
        (loadStateStreamValue, loadStateContinuation) = AsyncStream<RoomListLoadState>.makeStream(bufferingPolicy: .unbounded)
    }

    func start() async throws {
        startCallCount += 1

        if let startError {
            throw startError
        }
    }

    func summaryDiffs() -> AsyncStream<[CollectionDiff<RoomSummary>]> {
        diffStream
    }

    func loadingStateStream() -> AsyncStream<RoomListLoadState> {
        loadStateStreamValue
    }

    func setFilter(_ filter: RoomListFilter) {
        appliedFilters.append(filter)
    }

    func loadMore() {
        loadMoreCallCount += 1
    }

    func subscribeToVisibleRooms(ids: [String]) async {
        subscribedVisibleRoomIDs.append(ids)
    }

    func shutdown() {
        shutdownCallCount += 1
    }

    /// Pushes one diff batch to whoever is observing `summaryDiffs()`.
    func emit(diffs: [CollectionDiff<RoomSummary>]) {
        diffContinuation.yield(diffs)
    }

    /// Pushes one load state to whoever is observing `loadingStateStream()`.
    func emit(loadState: RoomListLoadState) {
        loadStateContinuation.yield(loadState)
    }
}
