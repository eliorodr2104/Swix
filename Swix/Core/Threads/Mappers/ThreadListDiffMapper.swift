//
//  ThreadListDiffMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Turns the two things a thread list subscription emits, item diffs and pagination state, into
/// their Core equivalents.
///
/// The eleven diff cases are the same eleven the room list and every timeline use, which is why they
/// land in the shared `CollectionDiff` instead of a thread specific type: one applier serves all
/// three, and a batch stays a batch all the way to the array it is applied to.
enum ThreadListDiffMapper {

    /// Maps one batch of SDK updates, preserving its order.
    ///
    /// The whole batch is mapped before anything is published so the repository can apply it as a
    /// single atomic update: a list that renders half a batch shows rows in positions the SDK never
    /// put them in.
    static func makeDiffs(from updates: [ThreadListUpdate]) -> [CollectionDiff<ThreadEntry>] {
        updates.map { makeDiff(from: $0) }
    }

    /// Maps the SDK's pagination state, whose idle case also carries whether the last page has
    /// already been handed over.
    static func makeState(from state: ThreadListPaginationState) -> ThreadListState {
        switch state {
            case .idle(let endReached): .idle(hasReachedEnd: endReached)
            case .loading: .loading
        }
    }

    private static func makeDiff(from update: ThreadListUpdate) -> CollectionDiff<ThreadEntry> {
        switch update {
            case .append(let values):
                return .append(makeEntries(from: values))

            case .clear:
                return .clear

            case .pushFront(let value):
                return .pushFront(ThreadEntryMapper.makeEntry(from: value))

            case .pushBack(let value):
                return .pushBack(ThreadEntryMapper.makeEntry(from: value))

            case .popFront:
                return .popFront

            case .popBack:
                return .popBack

            case .insert(let index, let value):
                return .insert(
                    index  : Int(index),
                    element: ThreadEntryMapper.makeEntry(from: value)
                )

            case .set(let index, let value):
                return .set(
                    index  : Int(index),
                    element: ThreadEntryMapper.makeEntry(from: value)
                )

            case .remove(let index):
                return .remove(index: Int(index))

            case .truncate(let length):
                return .truncate(length: Int(length))

            case .reset(let values):
                return .reset(makeEntries(from: values))
        }
    }

    private static func makeEntries(from items: [ThreadListItem]) -> [ThreadEntry] {
        items.map { ThreadEntryMapper.makeEntry(from: $0) }
    }
}
