//
//  RoomListDiffMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Turns the two things the SDK's room list stream emits, entry diffs and load states, into their
/// Core equivalents.
enum RoomListDiffMapper {

    /// Maps one batch of SDK updates into domain diffs.
    ///
    /// Mapping has to be asynchronous because every summary needs the room's info and latest
    /// event, so the whole batch is resolved here and reaches the repository as a single atomic
    /// update instead of trickling into the list room by room.
    static func makeDiffs(from updates: [RoomListEntriesUpdate]) async -> [CollectionDiff<RoomSummary>] {
        var diffs: [CollectionDiff<RoomSummary>] = []

        diffs.reserveCapacity(updates.count)

        for update in updates {
            diffs.append(await makeDiff(from: update))
        }

        return diffs
    }

    /// Maps the SDK's own loading state, whose room count is a `UInt32` the UI never wants.
    static func makeLoadState(from state: RoomListLoadingState) -> RoomListLoadState {
        switch state {
            case .notLoaded: .notLoaded
            case .loaded(let maximumNumberOfRooms): .loaded(totalRoomCount: maximumNumberOfRooms.map(Int.init))
        }
    }

    /// Maps a single SDK update to its domain equivalent, resolving whichever room payload it
    /// carries along the way.
    private static func makeDiff(from update: RoomListEntriesUpdate) async -> CollectionDiff<RoomSummary> {
        switch update {
            case .append(let values):
                return .append(await makeSummaries(from: values))

            case .clear:
                return .clear

            case .pushFront(let value):
                return .pushFront(await RoomSummaryMapper.makeSummary(from: value))

            case .pushBack(let value):
                return .pushBack(await RoomSummaryMapper.makeSummary(from: value))

            case .popFront:
                return .popFront

            case .popBack:
                return .popBack

            case .insert(let index, let value):
                return .insert(index: Int(index), element: await RoomSummaryMapper.makeSummary(from: value))

            case .set(let index, let value):
                return .set(index: Int(index), element: await RoomSummaryMapper.makeSummary(from: value))

            case .remove(let index):
                return .remove(index: Int(index))

            case .truncate(let length):
                return .truncate(length: Int(length))

            case .reset(let values):
                return .reset(await makeSummaries(from: values))
        }
    }

    /// Resolves a whole page of rooms in order, which is what keeps an `append` or `reset` batch
    /// atomic instead of letting rows trickle into the list one at a time.
    private static func makeSummaries(from rooms: [Room]) async -> [RoomSummary] {
        var summaries: [RoomSummary] = []

        summaries.reserveCapacity(rooms.count)

        for room in rooms {
            summaries.append(await RoomSummaryMapper.makeSummary(from: room))
        }

        return summaries
    }
}
