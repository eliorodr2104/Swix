//
//  RoomListEntriesServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Owns the SDK's dynamic room list and publishes it as domain diffs.
protocol RoomListEntriesServiceProtocol {

    /// Builds the dynamic entries adapter and starts emitting. Calling it again is a no op.
    func start() async throws

    /// Room list changes, already resolved into domain summaries and batched exactly as the SDK
    /// batched them, so one emission is one atomic UI update.
    func summaryDiffs() -> AsyncStream<[CollectionDiff<RoomSummary>]>

    /// Whether the first page has arrived, and how many rooms exist in total when known.
    func loadingStateStream() -> AsyncStream<RoomListLoadState>

    /// Replaces the active filter. The new selection arrives as an ordinary diff batch.
    func setFilter(_ filter: RoomListFilter)

    /// Asks the adapter for one more page of rooms.
    func loadMore()

    /// Tells the server which rooms are on screen so their state is kept fresh. Best effort: a
    /// failure here only costs freshness, never correctness.
    func subscribeToVisibleRooms(ids: [String]) async

    /// Releases every subscription this service owns. Called once, when the session ends.
    func shutdown()
}
