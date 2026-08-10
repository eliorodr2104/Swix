//
//  TimelineDiffMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Turns the two things a timeline subscription emits, item diffs and back pagination status, into
/// their Core equivalents.
///
/// The eleven diff cases are the same eleven the room list uses, which is why they land in the
/// shared `CollectionDiff` instead of a timeline specific type: one applier serves both, and a
/// batch stays a batch all the way to the array it is applied to.
enum TimelineDiffMapper {

    /// Maps one batch of SDK diffs, preserving its order.
    ///
    /// The whole batch is mapped before anything is published so the repository can apply it as a
    /// single atomic update: a timeline that renders half a batch shows rows in positions the SDK
    /// never put them in.
    static func makeDiffs(
        from diffs: [TimelineDiff],
        ownUserID : String?
    ) -> [CollectionDiff<TimelineEntry>] {

        diffs.map { makeDiff(from: $0, ownUserID: ownUserID) }
    }

    /// Maps the SDK's back pagination status, whose "idle" case also carries whether the start of
    /// the room has been reached.
    static func makePaginationState(from status: PaginationStatus) -> PaginationState {
        switch status {
            case .idle(let hitTimelineStart): .idle(hasReachedStart: hitTimelineStart)
            case .paginating: .paginating
        }
    }

    private static func makeDiff(
        from diff: TimelineDiff,
        ownUserID: String?
    ) -> CollectionDiff<TimelineEntry> {

        switch diff {
            case .append(let values):
                return .append(makeEntries(from: values, ownUserID: ownUserID))

            case .clear:
                return .clear

            case .pushFront(let value):
                return .pushFront(makeEntry(from: value, ownUserID: ownUserID))

            case .pushBack(let value):
                return .pushBack(makeEntry(from: value, ownUserID: ownUserID))

            case .popFront:
                return .popFront

            case .popBack:
                return .popBack

            case .insert(let index, let value):
                return .insert(
                    index  : Int(index),
                    element: makeEntry(from: value, ownUserID: ownUserID)
                )

            case .set(let index, let value):
                return .set(
                    index  : Int(index),
                    element: makeEntry(from: value, ownUserID: ownUserID)
                )

            case .remove(let index):
                return .remove(index: Int(index))

            case .truncate(let length):
                return .truncate(length: Int(length))

            case .reset(let values):
                return .reset(makeEntries(from: values, ownUserID: ownUserID))
        }
    }

    private static func makeEntries(
        from items: [TimelineItem],
        ownUserID : String?
    ) -> [TimelineEntry] {

        items.map { makeEntry(from: $0, ownUserID: ownUserID) }
    }

    private static func makeEntry(
        from item: TimelineItem,
        ownUserID: String?
    ) -> TimelineEntry {

        TimelineEntryMapper.makeEntry(from: item, ownUserID: ownUserID)
    }
}
