//
//  SendQueueEvent.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Something the room's send queue did to a message the user sent.
///
/// These arrive out of band from the timeline diffs, keyed by transaction id, because the queue
/// lives longer than any timeline instance: a message can be queued, wedged and retried while the
/// user is looking at another room entirely.
enum SendQueueEvent: Equatable {

    /// The message entered the queue and is on its way out.
    case queued(transactionID: String)

    /// The user aborted the message before it left.
    case cancelled(transactionID: String)

    /// An edit replaced the message while it was still queued.
    case replaced(transactionID: String)

    /// Sending failed for the stated reason.
    ///
    /// A recoverable failure also disabled the whole room's queue, so nothing else will go out
    /// until it is explicitly re-enabled; an unrecoverable one leaves the message parked.
    case failed(
        transactionID: String,
        reason       : String,
        isRecoverable: Bool
    )

    /// The queue picked the message back up after a failure.
    case retrying(transactionID: String)

    /// The homeserver accepted the message and gave it this event id.
    case sent(
        transactionID: String,
        eventID      : String
    )

    /// An attachment attached to a queued message made upload progress, from zero to one.
    case uploadProgress(
        relatedTo: String,
        fraction : Double
    )

    /// The transaction id the event refers to, which is how a local echo is found in the timeline.
    ///
    /// Upload progress is the odd one out: it names the media event it belongs to rather than a
    /// queue transaction, so it carries no transaction id of its own.
    var transactionID: String? {
        switch self {
            case .queued(let transactionID)      : transactionID
            case .cancelled(let transactionID)   : transactionID
            case .replaced(let transactionID)    : transactionID
            case .failed(let transactionID, _, _): transactionID
            case .retrying(let transactionID)    : transactionID
            case .sent(let transactionID, _)     : transactionID
            case .uploadProgress                 : nil
        }
    }

    /// The send state this event puts the message in, nil for the events that only report progress
    /// without moving the message anywhere.
    var sendState: TimelineSendState? {
        switch self {
            case .queued, .retrying: .sending
            case .sent(_, let eventID): .sent(eventID: eventID)

            case .failed(_, let reason, let isRecoverable):
                .failed(reason: reason, isRecoverable: isRecoverable)

            case .cancelled, .replaced, .uploadProgress: nil
        }
    }
}
