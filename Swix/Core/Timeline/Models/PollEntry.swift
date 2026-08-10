//
//  PollEntry.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// A poll as it stands right now, tally included.
///
/// A poll is a message that keeps changing: every vote and the closing event arrive as ordinary
/// timeline updates, and the SDK republishes the whole aggregated poll each time. So this is a
/// snapshot, never a running total accumulated on our side.
struct PollEntry: Identifiable, Equatable {

    /// The SDK's unique id for the timeline item, stable across votes and edits.
    let id: String

    /// How the poll's start event is addressed when voting on it, ending it or redacting it.
    let eventIdentifier: EventIdentifier

    /// The Matrix user id of whoever started the poll.
    let sender: String

    /// The sender's display name, absent while the profile is still resolving.
    let senderDisplayName: String?

    /// The question, as the poll's author wrote it.
    let question: String

    /// The options, in the order they were offered, each carrying its own tally.
    let answers: [PollAnswerEntry]

    /// Whether the running tally is public while the poll is open.
    let kind: PollVisibility

    /// How many options one person is allowed to pick.
    let maxSelections: Int

    /// When the poll was started.
    let timestamp: Date

    /// Whether the signed in account started this poll, which is what allows ending it.
    let isOwn: Bool

    /// Whether the question or the options were edited after the poll went out.
    let isEdited: Bool

    /// When the poll was closed, nil while it is still open.
    let endDate: Date?

    /// Where the poll stands with the send queue, absent once it came back from sync.
    var sendState: TimelineSendState?

    /// Emoji reactions on the poll's start event.
    let reactions: [ReactionInfo]

    /// Read receipts that landed on the poll's start event.
    let readReceipts: [ReceiptInfo]

    /// The best name available for the sender, falling back to the raw user id.
    var displayName: String {
        senderDisplayName ?? sender
    }

    /// Whether voting is closed.
    var isEnded: Bool {
        endDate != nil
    }

    /// Whether one person may pick more than one option, which is what turns the radio buttons
    /// into checkboxes.
    var isMultipleChoice: Bool {
        maxSelections > 1
    }

    /// Ids of the options the signed in account picked, empty when they have not voted.
    var ownAnswerIDs: [String] {
        answers.filter(\.isOwnVote).map(\.id)
    }

    /// Whether the signed in account has voted at all.
    var hasVoted: Bool {
        !ownAnswerIDs.isEmpty
    }

    /// Total votes cast across every option, for rendering each bar as a share of the whole.
    var totalVoteCount: Int {
        answers.reduce(0) { $0 + $1.voteCount }
    }

    /// Whether the tally can be shown yet: an undisclosed poll keeps its counts until it ends.
    var isShowingResults: Bool {
        kind == .disclosed || isEnded
    }
}
