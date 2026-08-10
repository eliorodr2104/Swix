//
//  OutgoingMessage.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// What the composer hands over when the user presses send.
///
/// The text stays markdown all the way down: the SDK turns it into both the plain body and the
/// formatted one, so formatting the message here would only mean undoing it later.
struct OutgoingMessage: Equatable {

    /// The message as the user typed it, interpreted as markdown.
    let markdown: String

    /// The event this message replies to, nil for a plain message.
    let replyToEventID: String?

    init(
        markdown      : String,
        replyToEventID: String? = nil
    ) {
        self.markdown       = markdown
        self.replyToEventID = replyToEventID
    }

    /// Whether there is nothing worth sending, so the send button stays disabled.
    var isEmpty: Bool {
        markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
