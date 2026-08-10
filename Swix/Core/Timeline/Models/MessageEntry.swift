//
//  MessageEntry.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// A message bubble, flattened from whatever the SDK's content model happened to hold.
///
/// `sendState` is the one mutable field because the send queue reports progress out of band, and
/// updating it in place keeps the array indices the SDK's diffs are expressed in untouched.
struct MessageEntry: Identifiable, Equatable {

    /// The SDK's unique id for the timeline item, stable across edits and re-sends.
    let id: String

    /// How the event is addressed when editing, redacting or retrying it.
    let eventIdentifier: EventIdentifier

    /// The Matrix user id of whoever sent the message.
    let sender: String

    /// The sender's display name, absent while the profile is still resolving.
    let senderDisplayName: String?

    /// The text to render, already falling back to a filename or a caption for attachments.
    let body: String

    /// When the event was sent, converted from the SDK's milliseconds since the epoch.
    let timestamp: Date

    /// Whether the signed in account sent this message.
    let isOwn: Bool

    /// Whether the message has been edited at least once.
    let isEdited: Bool

    /// Whether the signed in account is still allowed to edit it.
    let isEditable: Bool

    /// Where the message stands with the send queue, absent for events that came from sync.
    var sendState: TimelineSendState?

    /// The attachment this message carries, absent for plain text.
    let mediaKind: MessageMediaKind?

    /// Emoji reactions on this message, one entry per key with its senders already grouped.
    let reactions: [ReactionInfo]

    /// Who has read up to this message, sorted by user id so the list stays stable between
    /// updates rather than reshuffling every time the SDK republishes the item.
    let readReceipts: [ReceiptInfo]

    /// Whether the message could not be decrypted, which is a bubble of its own rather than text.
    let isUndecryptable: Bool

    /// The best name available for the sender, falling back to the raw user id.
    var displayName: String {
        senderDisplayName ?? sender
    }

    /// Whether the message failed to send and is waiting for the user to retry it.
    var isFailed: Bool {
        sendState?.isFailed ?? false
    }

    /// Whether the message is still on its way to the homeserver.
    var isPending: Bool {
        sendState?.isPending ?? false
    }

    /// Whether the message carries an attachment of any kind.
    var hasMedia: Bool {
        mediaKind != nil
    }

    /// Whether anyone reacted to this message.
    var hasReactions: Bool {
        !reactions.isEmpty
    }
}
