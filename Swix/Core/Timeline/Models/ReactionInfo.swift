//
//  ReactionInfo.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// One emoji reaction on an event, with everybody who sent it already grouped under it.
///
/// The SDK hands reactions over as one entry per key with the senders listed inside, which is
/// exactly the shape a row of reaction pills wants, so nothing is regrouped here.
struct ReactionInfo: Identifiable, Equatable {

    /// The reaction itself, usually a single emoji but the spec allows any short string.
    let key: String

    /// Matrix user ids of everybody who reacted with this key, in the order the SDK listed them.
    let senderIDs: [String]

    /// Whether the signed in account is one of those senders, which is what makes the pill
    /// highlighted and turns a tap into a removal.
    let isOwn: Bool

    /// The key doubles as the identity: a timeline item never carries the same key twice.
    var id: String {
        key
    }

    /// How many people reacted with this key.
    var count: Int {
        senderIDs.count
    }
}
