//
//  TimelineEntry.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// One row of a room's timeline, whatever kind of thing the SDK put there.
///
/// The SDK mixes real events with rows that exist only for layout, the date dividers and the read
/// marker, and reports all of them as a single ordered collection of diffs. Modelling both as cases
/// of one enum is what lets those diffs be applied straight to an array, with no side table to keep
/// in step.
enum TimelineEntry: Identifiable, Equatable {

    /// A message bubble, the kind of row the user can reply to, edit or react to.
    case message(MessageEntry)

    /// A poll, which behaves like a message but renders its own options and tally.
    case poll(PollEntry)

    /// A one line note about the room rather than the conversation.
    case notice(TimelineNotice)

    /// The day separator the SDK inserts wherever the date changes.
    case dateSeparator(
        id  : String,
        date: Date
    )

    /// Where the user's read marker sits, positioned for us by the SDK.
    case readMarker(id: String)

    /// The very beginning of the room's history, so back pagination has nothing left to fetch.
    case timelineStart(id: String)

    /// The SDK's own unique id for the row, stable across edits, re-sends and pagination, which is
    /// what SwiftUI needs to animate the list instead of rebuilding it.
    var id: String {
        switch self {
            case .message(let entry)      : entry.id
            case .poll(let entry)         : entry.id
            case .notice(let notice)      : notice.id
            case .dateSeparator(let id, _): id
            case .readMarker(let id)      : id
            case .timelineStart(let id)   : id
        }
    }

    /// The message on this row, nil for every other kind of row.
    var message: MessageEntry? {
        guard case .message(let entry) = self else {
            return nil
        }

        return entry
    }

    /// The poll on this row, nil for every other kind of row.
    var poll: PollEntry? {
        guard case .poll(let entry) = self else {
            return nil
        }

        return entry
    }

    /// How the underlying event is addressed, nil for the rows that are not events.
    var eventIdentifier: EventIdentifier? {
        switch self {
            case .message(let entry): entry.eventIdentifier
            case .poll(let entry)   : entry.eventIdentifier
            case .notice, .dateSeparator, .readMarker, .timelineStart: nil
        }
    }

    /// When the row happened, nil for the rows the SDK does not timestamp.
    var timestamp: Date? {
        switch self {
            case .message(let entry)      : entry.timestamp
            case .poll(let entry)         : entry.timestamp
            case .notice(let notice)      : notice.timestamp
            case .dateSeparator(_, let date): date
            case .readMarker, .timelineStart: nil
        }
    }

    /// Whether the signed in account produced this row.
    var isOwn: Bool {
        switch self {
            case .message(let entry): entry.isOwn
            case .poll(let entry)   : entry.isOwn
            case .notice, .dateSeparator, .readMarker, .timelineStart: false
        }
    }

    /// Replaces the send state of the message or poll on this row, leaving layout rows alone.
    ///
    /// Rewriting the entry in place is what keeps the array indices the SDK's diffs are expressed
    /// in valid: a send queue update never changes the shape of the list, only one row's state.
    mutating func updateSendState(_ sendState: TimelineSendState?) {
        switch self {
            case .message(var entry):
                entry.sendState = sendState
                self = .message(entry)

            case .poll(var entry):
                entry.sendState = sendState
                self = .poll(entry)

            case .notice, .dateSeparator, .readMarker, .timelineStart:
                break
        }
    }
}
