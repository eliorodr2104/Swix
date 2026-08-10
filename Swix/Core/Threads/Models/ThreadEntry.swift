//
//  ThreadEntry.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// One thread of a room, as the thread list shows it.
///
/// The SDK resolves the sender profiles eagerly and parses the event content before handing an item
/// over, so a row needs nothing else to render: every field here is a plain read off the SDK's own
/// thread list item.
///
/// `subscription` is the one mutable field, and the only one the list itself says nothing about:
/// whether the account follows a thread is a separate request per thread, so a row starts out
/// `.unknown` and is patched in place once somebody asks.
struct ThreadEntry: Identifiable, Equatable {

    /// The event that started the thread, which is also how every thread operation names it.
    let rootEventID: String

    /// One line summary of the root message, already collapsed and already given a label when the
    /// root is an attachment rather than text.
    let rootPreviewText: String

    /// Best name available for whoever started the thread, falling back to the raw user id.
    let senderName: String

    /// Whether the signed in account started the thread.
    let isOwn: Bool

    /// When the thread started.
    let rootTimestamp: Date

    /// One line summary of the most recent reply, absent for a thread nobody has replied to.
    let lastReplyPreviewText: String?

    /// Best name available for whoever replied last, absent along with the reply itself.
    let lastReplySenderName: String?

    /// When the most recent reply landed, absent for a thread nobody has replied to.
    let lastReplyTimestamp: Date?

    /// How many replies the thread has, the root event not counted.
    let replyCount: Int

    /// Whether the account follows this thread, `.unknown` until somebody asks the homeserver.
    var subscription: ThreadSubscriptionState

    /// The SDK keys a thread by its root event, so that id is identity enough.
    var id: String {
        rootEventID
    }

    /// Whether anybody has replied yet.
    var hasReplies: Bool {
        replyCount > 0
    }

    /// Whether the account follows this thread right now.
    var isSubscribed: Bool {
        subscription.isSubscribed
    }

    /// When the thread last moved, which is what a list of threads timestamps and sorts on. A thread
    /// with no replies has only ever moved once, when it started.
    var lastActivity: Date {
        lastReplyTimestamp ?? rootTimestamp
    }
}
