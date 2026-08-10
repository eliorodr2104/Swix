//
//  ThreadListService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import os


/// The default `ThreadListServiceProtocol`, built on `Room.threadListService()`.
///
/// The SDK exports a `ThreadListService` of its own, which this name shadows on purpose: the two are
/// the same concept on opposite sides of the FFI, and the two places that need the Rust one spell it
/// out as `MatrixRustSDK.ThreadListService`.
final class ThreadListService: ThreadListServiceProtocol {

    let roomID: String

    let entryDiffs: AsyncStream<[CollectionDiff<ThreadEntry>]>

    let listStates: AsyncStream<ThreadListState>

    private let roomProvider: any RoomProviding

    private let diffContinuation: AsyncStream<[CollectionDiff<ThreadEntry>]>.Continuation

    private let stateContinuation: AsyncStream<ThreadListState>.Continuation

    private let subscriptions = SubscriptionBag()

    // The SDK service is kept for as long as the screen stays open: it is what the two listeners
    // were registered on, and it also holds the pagination token, so asking the room for another one
    // would hand back an empty list that starts paginating from the top again.
    private var listService: MatrixRustSDK.ThreadListService?

    // The listeners are Rust's only route back into this process. The TaskHandles in the bag keep
    // the subscriptions alive, these keep the adapters that feed the streams alive.
    private var entriesListener: SDKListener<[ThreadListUpdate]>?

    private var stateListener: SDKListener<ThreadListPaginationState>?

    init(
        roomID      : String,
        roomProvider: any RoomProviding
    ) {
        self.roomID       = roomID
        self.roomProvider = roomProvider

        (entryDiffs, diffContinuation) = AsyncStream<[CollectionDiff<ThreadEntry>]>.makeStream(bufferingPolicy: .unbounded)
        (listStates, stateContinuation) = AsyncStream<ThreadListState>.makeStream(bufferingPolicy: .unbounded)
    }

    func start() async throws {
        guard listService == nil else {
            return
        }

        let room = try activeRoom()
        let listService = room.threadListService()

        self.listService = listService

        observeEntries(of: listService)
        observeState(of: listService)

        Log.timeline.notice("Thread list attached to room \(self.roomID, privacy: .public)")

        // The item listener only replays what is already loaded, and a fresh list holds nothing at
        // all, so the opening page is fetched here rather than left to whoever scrolls first.
        try await loadPage(of: listService)
    }

    func paginate() async throws {
        guard let listService else {
            throw ThreadsFailure.notStarted
        }

        try await loadPage(of: listService)
    }

    func reset() async {
        await listService?.reset()
    }

    func shutdown() {
        subscriptions.cancelAll()

        entriesListener = nil
        stateListener   = nil
        listService     = nil
    }

    /// `RoomProviding` fails with our own `SyncFailure` only when sync never ran, which is worth
    /// telling apart from a room the list genuinely does not have.
    private func activeRoom() throws -> Room {
        do {
            return try roomProvider.room(withId: roomID)

        } catch is SyncFailure {
            throw ThreadsFailure.notStarted

        } catch { throw ThreadsFailure.roomUnavailable(SDKErrorInfo(error)) }
    }

    private func loadPage(of listService: MatrixRustSDK.ThreadListService) async throws {
        do {
            try await listService.paginate()

        } catch { throw ThreadsFailure.paginationFailed(SDKErrorInfo(error)) }
    }

    private func observeEntries(of listService: MatrixRustSDK.ThreadListService) {
        let (updates, listener) = makeSDKStream(of: [ThreadListUpdate].self)

        entriesListener = listener

        subscriptions.retain(listService.subscribeToItemsUpdates(listener: listener))
        subscriptions.retain(
            Task { [diffContinuation] in
                for await batch in updates {
                    diffContinuation.yield(ThreadListDiffMapper.makeDiffs(from: batch))
                }
            }
        )
    }

    /// The pagination listener is called once per transition and never for the state the list is
    /// already in, so publishing that one here is what keeps a subscriber from sitting on a guess.
    private func observeState(of listService: MatrixRustSDK.ThreadListService) {
        let (states, listener) = makeSDKStream(of: ThreadListPaginationState.self)

        stateListener = listener

        subscriptions.retain(listService.subscribeToPaginationStateUpdates(listener: listener))
        stateContinuation.yield(
            ThreadListDiffMapper.makeState(from: listService.paginationState())
        )

        subscriptions.retain(
            Task { [stateContinuation] in
                for await state in states {
                    stateContinuation.yield(ThreadListDiffMapper.makeState(from: state))
                }
            }
        )
    }
}
