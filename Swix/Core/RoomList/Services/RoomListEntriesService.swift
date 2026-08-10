//
//  RoomListEntriesService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import MatrixRustSDK
import os


/// The default `RoomListEntriesServiceProtocol`, built on `RoomList.entriesWithDynamicAdapters`.
final class RoomListEntriesService: RoomListEntriesServiceProtocol {

    private let coordinator: any SyncCoordinatorProtocol

    private let pageSize: UInt32

    private let diffStream: AsyncStream<[CollectionDiff<RoomSummary>]>

    private let diffContinuation: AsyncStream<[CollectionDiff<RoomSummary>]>.Continuation

    private let loadStateStream: AsyncStream<RoomListLoadState>

    private let loadStateContinuation: AsyncStream<RoomListLoadState>.Continuation

    private let subscriptions = SubscriptionBag()

    private var entriesResult: RoomListEntriesWithDynamicAdaptersResult?

    private var controller: RoomListDynamicEntriesController?

    private var entriesListener: SDKListener<[RoomListEntriesUpdate]>?

    private var loadingStateListener: SDKListener<RoomListLoadingState>?

    private var activeFilter: RoomListFilter = .all

    private var isStarted = false

    init(
        coordinator: any SyncCoordinatorProtocol,
        pageSize   : UInt32 = MatrixConfiguration.roomListPageSize
    ) {
        self.coordinator = coordinator
        self.pageSize    = pageSize

        (diffStream, diffContinuation) = AsyncStream<[CollectionDiff<RoomSummary>]>.makeStream(bufferingPolicy: .unbounded)
        (loadStateStream, loadStateContinuation) = AsyncStream<RoomListLoadState>.makeStream(bufferingPolicy: .unbounded)
    }

    func start() async throws {
        guard !isStarted else {
            return
        }

        guard let roomListService = try? coordinator.roomListService() else {
            throw RoomListFailure.notStarted
        }

        do {
            let roomList = try await roomListService.allRooms()

            isStarted = true

            observeEntries(of: roomList)
            observeLoadingState(of: roomList)
        } catch {
            throw RoomListFailure.listUnavailable(SDKErrorInfo(error))
        }
    }

    func summaryDiffs() -> AsyncStream<[CollectionDiff<RoomSummary>]> {
        diffStream
    }

    func loadingStateStream() -> AsyncStream<RoomListLoadState> {
        loadStateStream
    }

    func setFilter(_ filter: RoomListFilter) {
        activeFilter = filter

        applyActiveFilter()
    }

    func loadMore() {
        controller?.addOnePage()
    }

    func subscribeToVisibleRooms(ids: [String]) async {
        guard !ids.isEmpty, let roomListService = try? coordinator.roomListService() else {
            return
        }

        do {
            try await roomListService.subscribeToRooms(roomIds: ids)
        } catch {
            Log.roomList.warning("Could not subscribe to visible rooms: \(String(reflecting: error), privacy: .public)")
        }
    }

    func shutdown() {
        subscriptions.cancelAll()

        controller           = nil
        entriesResult        = nil
        entriesListener      = nil
        loadingStateListener = nil
        isStarted            = false
    }

    /// Wires up the dynamic entries adapter and applies whichever filter is active, since the
    /// adapter otherwise stays completely silent forever.
    private func observeEntries(of roomList: RoomList) {
        let (updates, listener) = makeSDKStream(of: [RoomListEntriesUpdate].self)
        let result = roomList.entriesWithDynamicAdapters(pageSize: pageSize, listener: listener)

        entriesListener = listener
        entriesResult   = result
        controller      = result.controller()

        subscriptions.retain(result.entriesStream())

        // The dynamic adapter stays completely silent until a filter is installed, so the initial
        // one is applied here instead of waiting for the user to touch anything.
        applyActiveFilter()

        subscriptions.retain(Task { [diffContinuation] in
            for await update in updates {
                diffContinuation.yield(await RoomListDiffMapper.makeDiffs(from: update))
            }
        })
    }

    /// Publishes the loading state the SDK already holds and then keeps forwarding every change,
    /// the same "publish current, then forward" pattern the diff stream uses.
    private func observeLoadingState(of roomList: RoomList) {
        let (states, listener) = makeSDKStream(of: RoomListLoadingState.self)

        do {
            let result = try roomList.loadingState(listener: listener)

            loadingStateListener = listener

            subscriptions.retain(result.stateStream)
            loadStateContinuation.yield(RoomListDiffMapper.makeLoadState(from: result.state))

            subscriptions.retain(Task { [loadStateContinuation] in
                for await state in states {
                    loadStateContinuation.yield(RoomListDiffMapper.makeLoadState(from: state))
                }
            })
        } catch {
            Log.roomList.error("Could not observe room list loading state: \(String(reflecting: error), privacy: .public)")
        }
    }

    /// Installs the current filter on the controller, logging rather than throwing because a
    /// refused filter is a bug worth noticing, not a failure the caller can act on.
    private func applyActiveFilter() {
        guard let controller else {
            return
        }

        let isApplied = controller.setFilter(kind: Self.makeFilterKind(from: activeFilter))

        if !isApplied {
            Log.roomList.warning("Room list refused filter \(String(describing: self.activeFilter), privacy: .public)")
        }
    }

    /// Every filter is combined with `nonLeft` so a room the user abandoned never comes back just
    /// because it still matches the selection.
    private static func makeFilterKind(from filter: RoomListFilter) -> RoomListEntriesDynamicFilterKind {
        switch filter {
            case .all: .nonLeft
            case .favourites: .all(filters: [.nonLeft, .favourite])
            case .unread: .all(filters: [.nonLeft, .unread])
            case .people: .all(filters: [.nonLeft, .category(expect: .people)])
            case .groups: .all(filters: [.nonLeft, .category(expect: .group)])
            case .search(let pattern): makeSearchFilterKind(pattern: pattern)
        }
    }

    /// A search falls back to fuzzy matching only once the pattern is long enough to be worth it,
    /// since a fuzzy match on one or two characters returns essentially the whole list.
    private static func makeSearchFilterKind(pattern: String) -> RoomListEntriesDynamicFilterKind {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return .nonLeft
        }

        if trimmed.count < 3 {
            return .all(filters: [.nonLeft, .normalizedMatchRoomName(pattern: trimmed)])
        }

        return .all(filters: [.nonLeft, .fuzzyMatchRoomName(pattern: trimmed)])
    }
}
