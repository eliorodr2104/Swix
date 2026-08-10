//
//  ThreadListDiffMapperTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Testing
@testable import Swix


@Suite("ThreadListDiffMapper")
struct ThreadListDiffMapperTests {

    @Test("idle pagination carries whether the end was reached")
    func idleStateCarriesEndReached() {
        #expect(ThreadListDiffMapper.makeState(from: .idle(endReached: true)) == .idle(hasReachedEnd: true))
        #expect(ThreadListDiffMapper.makeState(from: .idle(endReached: false)) == .idle(hasReachedEnd: false))
    }

    @Test("loading pagination maps to loading")
    func loadingStateMapsToLoading() {
        #expect(ThreadListDiffMapper.makeState(from: .loading) == .loading)
    }

    @Test("a reset batch preserves order and maps every item")
    func resetBatchMapsInOrder() {
        let updates: [ThreadListUpdate] = [
            .reset(values: [Self.makeItem(eventID: "$a"), Self.makeItem(eventID: "$b")])
        ]

        let diffs = ThreadListDiffMapper.makeDiffs(from: updates)

        guard case .reset(let entries) = diffs.first else {
            Issue.record("expected a reset diff")
            return
        }

        #expect(entries.map(\.rootEventID) == ["$a", "$b"])
    }

    @Test("index carrying updates convert their index from UInt32 to Int")
    func indexCarryingUpdatesConvertIndex() {
        let updates: [ThreadListUpdate] = [
            .insert(index: 2, value: Self.makeItem(eventID: "$c")),
            .remove(index: 1)
        ]

        let diffs = ThreadListDiffMapper.makeDiffs(from: updates)

        guard case .insert(let index, let element) = diffs[0] else {
            Issue.record("expected an insert diff")
            return
        }

        #expect(index == 2)
        #expect(element.rootEventID == "$c")

        guard case .remove(let removeIndex) = diffs[1] else {
            Issue.record("expected a remove diff")
            return
        }

        #expect(removeIndex == 1)
    }

    @Test("a fresh entry's subscription always starts unknown")
    func mappedEntryStartsUnknown() {
        let diffs = ThreadListDiffMapper.makeDiffs(from: [.pushBack(value: Self.makeItem(eventID: "$d"))])

        guard case .pushBack(let entry) = diffs.first else {
            Issue.record("expected a pushBack diff")
            return
        }

        #expect(entry.subscription == .unknown)
    }

    private static func makeItem(eventID: String) -> ThreadListItem {
        ThreadListItem(
            rootEvent: ThreadListItemEvent(
                eventId      : eventID,
                timestamp    : 0,
                sender       : "@alice:example.org",
                senderProfile: .unavailable,
                isOwn        : false,
                content      : nil
            ),
            latestEvent: nil,
            numReplies : 0
        )
    }
}
