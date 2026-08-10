//
//  TimelineSendState.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Where a message the user sent stands with the send queue.
///
/// Only outgoing messages carry one: an event that arrived from sync was never in a local queue,
/// so its send state is absent rather than `.sent`.
enum TimelineSendState: Equatable {

    /// Queued locally, not acknowledged by the homeserver yet.
    case sending

    /// Accepted by the homeserver, which assigned it this event id.
    case sent(eventID: String)

    /// The send queue gave up on this message for the stated reason.
    ///
    /// A recoverable failure stopped the whole room queue and can be retried once the cause is
    /// gone; an unrecoverable one stays parked until the user cancels or retries it explicitly.
    case failed(reason: String, isRecoverable: Bool)

    /// Whether the message is still on its way out.
    var isPending: Bool {
        self == .sending
    }

    /// Whether the message needs the user to do something about it.
    var isFailed: Bool {
        guard case .failed = self else {
            return false
        }

        return true
    }
}
