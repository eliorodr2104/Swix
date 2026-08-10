//
//  MessageSearchResult.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// One message the local full text index matched, already flattened into what a result row needs.
///
/// The SDK ships a type with the same name; this one is the domain model and always wins name
/// resolution inside the app module, so mappers spell the SDK's as `MatrixRustSDK.MessageSearchResult`.
struct MessageSearchResult: Equatable, Identifiable {

    /// Room the match belongs to, for opening the conversation at the right place.
    let roomID: String

    /// Name of that room when it is already known locally, nil while the room is not in the cache.
    let roomName: String?

    /// Event to scroll to once the room opens.
    let eventID: String

    /// Plain text shown in the result row, derived from whatever kind of event matched.
    let snippetText: String

    /// Matrix ID of the sender.
    let sender: String

    /// Sender's display name when the index resolved the profile, nil otherwise.
    let senderDisplayName: String?

    /// When the matched event was sent.
    let timestamp: Date

    /// Event IDs are unique across the account, which makes them a stable list identity.
    var id: String {
        eventID
    }

    /// What a row should print for the sender, falling back to the raw Matrix ID.
    var senderName: String {
        senderDisplayName ?? sender
    }
}
