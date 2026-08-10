//
//  TimelineEntryMapperTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
import MatrixRustSDK
@testable import Swix


@Suite("TimelineEntryMapper: poll and reaction mapping")
struct TimelineEntryMapperTests {

    private static let ownUserID = "@alice:example.org"

    // MARK: Reactions

    @Test("a reaction from someone else is not marked as the account's own")
    func reactionFromSomeoneElseIsNotOwn() {
        let event = Fixtures.eventTimelineItem(
            content: .msgLike(
                content: Fixtures.textMsgLikeContent(
                    reactions: [Reaction(key: "👍", senders: [ReactionSenderData(senderId: "@bob:example.org", timestamp: 0)])]
                )
            )
        )

        let entry = TimelineEntryMapper.makeEntry(
            from     : FakeTimelineItem(event: event, id: "item-1"),
            ownUserID: Self.ownUserID
        )

        let reactions = entry.message?.reactions ?? []

        #expect(reactions.count == 1)
        #expect(reactions.first?.key == "👍")
        #expect(reactions.first?.senderIDs == ["@bob:example.org"])
        #expect(reactions.first?.isOwn == false)
    }

    @Test("a reaction the account itself sent is marked as its own")
    func reactionFromTheAccountIsOwn() {
        let event = Fixtures.eventTimelineItem(
            content: .msgLike(
                content: Fixtures.textMsgLikeContent(
                    reactions: [
                        Reaction(
                            key    : "🎉",
                            senders: [
                                ReactionSenderData(senderId: "@bob:example.org", timestamp: 0),
                                ReactionSenderData(senderId: Self.ownUserID, timestamp: 0)
                            ]
                        )
                    ]
                )
            )
        )

        let entry = TimelineEntryMapper.makeEntry(
            from     : FakeTimelineItem(event: event, id: "item-1"),
            ownUserID: Self.ownUserID
        )

        let reaction = entry.message?.reactions.first

        #expect(reaction?.isOwn == true)
        #expect(reaction?.count == 2)
    }

    @Test("every reaction key on the event becomes its own pill, in order")
    func multipleReactionKeysStayGrouped() {
        let event = Fixtures.eventTimelineItem(
            content: .msgLike(
                content: Fixtures.textMsgLikeContent(
                    reactions: [
                        Reaction(key: "👍", senders: [ReactionSenderData(senderId: "@bob:example.org", timestamp: 0)]),
                        Reaction(key: "❤️", senders: [ReactionSenderData(senderId: "@carol:example.org", timestamp: 0)])
                    ]
                )
            )
        )

        let entry = TimelineEntryMapper.makeEntry(
            from     : FakeTimelineItem(event: event, id: "item-1"),
            ownUserID: Self.ownUserID
        )

        #expect(entry.message?.reactions.map(\.key) == ["👍", "❤️"])
        #expect(entry.message?.hasReactions == true)
    }

    @Test("nil ownUserID never marks a reaction as the account's own")
    func nilOwnUserIDNeverMatches() {
        let event = Fixtures.eventTimelineItem(
            content: .msgLike(
                content: Fixtures.textMsgLikeContent(
                    reactions: [Reaction(key: "👍", senders: [ReactionSenderData(senderId: "@bob:example.org", timestamp: 0)])]
                )
            )
        )

        let entry = TimelineEntryMapper.makeEntry(
            from     : FakeTimelineItem(event: event, id: "item-1"),
            ownUserID: nil
        )

        #expect(entry.message?.reactions.first?.isOwn == false)
    }

    // MARK: Polls

    @Test("an open poll maps every field, including a running tally")
    func openPollMapsEveryField() {
        let event = Fixtures.eventTimelineItem(
            eventOrTransactionId: .eventId(eventId: "$poll1"),
            isOwn               : true,
            content: .msgLike(
                content: Fixtures.pollMsgLikeContent(
                    question     : "Favourite color?",
                    kind         : .disclosed,
                    maxSelections: 1,
                    answers      : [
                        PollAnswer(id: "answer-1", text: "Red"),
                        PollAnswer(id: "answer-2", text: "Blue")
                    ],
                    votes: [
                        "answer-1": ["@bob:example.org", Self.ownUserID],
                        "answer-2": ["@carol:example.org"]
                    ]
                )
            )
        )

        let entry = TimelineEntryMapper.makeEntry(
            from     : FakeTimelineItem(event: event, id: "poll-1"),
            ownUserID: Self.ownUserID
        )

        guard let poll = entry.poll else {
            Issue.record("Expected a .poll entry")
            return
        }

        #expect(poll.question == "Favourite color?")
        #expect(poll.answers.map(\.text) == ["Red", "Blue"])
        #expect(poll.answers.map(\.voteCount) == [2, 1])
        #expect(poll.totalVoteCount == 3)
        #expect(poll.ownAnswerIDs == ["answer-1"])
        #expect(poll.hasVoted == true)
        #expect(poll.isOwn == true)
        #expect(poll.isEnded == false)
        #expect(poll.isMultipleChoice == false)
        #expect(poll.isShowingResults == true)
    }

    @Test("an undisclosed poll hides its tally until it ends")
    func undisclosedPollHidesResultsUntilEnded() {
        let openEvent = Fixtures.eventTimelineItem(
            content: .msgLike(
                content: Fixtures.pollMsgLikeContent(kind: .undisclosed, endTime: nil)
            )
        )

        let openEntry = TimelineEntryMapper.makeEntry(
            from     : FakeTimelineItem(event: openEvent, id: "poll-1"),
            ownUserID: Self.ownUserID
        )

        #expect(openEntry.poll?.isShowingResults == false)

        let closedEvent = Fixtures.eventTimelineItem(
            content: .msgLike(
                content: Fixtures.pollMsgLikeContent(kind: .undisclosed, endTime: 1_000)
            )
        )

        let closedEntry = TimelineEntryMapper.makeEntry(
            from     : FakeTimelineItem(event: closedEvent, id: "poll-2"),
            ownUserID: Self.ownUserID
        )

        #expect(closedEntry.poll?.isShowingResults == true)
        #expect(closedEntry.poll?.isEnded == true)
        #expect(closedEntry.poll?.endDate == TimelineEntryMapper.makeDate(from: 1_000))
    }

    @Test("a multiple choice poll reports more than one allowed selection")
    func multipleChoicePollReportsIsMultipleChoice() {
        let event = Fixtures.eventTimelineItem(
            content: .msgLike(content: Fixtures.pollMsgLikeContent(maxSelections: 2))
        )

        let entry = TimelineEntryMapper.makeEntry(
            from     : FakeTimelineItem(event: event, id: "poll-1"),
            ownUserID: Self.ownUserID
        )

        #expect(entry.poll?.isMultipleChoice == true)
    }

    @Test("an option nobody voted for reports a zero tally and no own vote")
    func unvotedOptionReportsZeroTally() {
        let event = Fixtures.eventTimelineItem(
            content: .msgLike(
                content: Fixtures.pollMsgLikeContent(votes: [:])
            )
        )

        let entry = TimelineEntryMapper.makeEntry(
            from     : FakeTimelineItem(event: event, id: "poll-1"),
            ownUserID: Self.ownUserID
        )

        #expect(entry.poll?.answers.allSatisfy { $0.voteCount == 0 && !$0.isOwnVote } == true)
        #expect(entry.poll?.hasVoted == false)
    }

    @Test("reactions on a poll's start event are mapped the same way as on a message")
    func pollReactionsAreMapped() {
        let event = Fixtures.eventTimelineItem(
            content: .msgLike(
                content: Fixtures.pollMsgLikeContent(
                    reactions: [Reaction(key: "👍", senders: [ReactionSenderData(senderId: Self.ownUserID, timestamp: 0)])]
                )
            )
        )

        let entry = TimelineEntryMapper.makeEntry(
            from     : FakeTimelineItem(event: event, id: "poll-1"),
            ownUserID: Self.ownUserID
        )

        #expect(entry.poll?.reactions.first?.isOwn == true)
    }

    // MARK: Send state, carried alongside reactions and poll tallies

    @Test("a local echo that has not been sent yet maps to sending")
    func notSentYetMapsToSending() {
        let event = Fixtures.eventTimelineItem(localSendState: .notSentYet(progress: nil))

        let entry = TimelineEntryMapper.makeEntry(
            from     : FakeTimelineItem(event: event, id: "item-1"),
            ownUserID: Self.ownUserID
        )

        #expect(entry.message?.sendState == .sending)
    }

    @Test("a send failure carries its reason and recoverability onto the row")
    func sendingFailedMapsToFailed() {
        let event = Fixtures.eventTimelineItem(
            localSendState: .sendingFailed(error: .crossVerificationRequired, isRecoverable: true)
        )

        let entry = TimelineEntryMapper.makeEntry(
            from     : FakeTimelineItem(event: event, id: "item-1"),
            ownUserID: Self.ownUserID
        )

        #expect(
            entry.message?.sendState ==
            .failed(
                reason       : SendQueueUpdateMapper.makeReason(from: .crossVerificationRequired),
                isRecoverable: true
            )
        )
    }

    @Test("a remote event with no local send state maps to nil, not sent")
    func remoteEventHasNoSendState() {
        let event = Fixtures.eventTimelineItem(localSendState: nil)

        let entry = TimelineEntryMapper.makeEntry(
            from     : FakeTimelineItem(event: event, id: "item-1"),
            ownUserID: Self.ownUserID
        )

        #expect(entry.message?.sendState == nil)
    }
}
