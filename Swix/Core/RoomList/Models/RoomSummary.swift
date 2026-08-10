//
//  RoomSummary.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// One row of the chat list, flattened out of the SDK's room and room info so views never touch
/// anything that has to be awaited or that could change under them mid render.
struct RoomSummary: Identifiable, Equatable {

    /// The Matrix room id, stable for the whole life of the room and used as the SwiftUI identity.
    let id: String

    /// What to title the row: the room's display name, falling back to its alias or its id.
    let name: String

    /// The room avatar, still an `mxc://` URL that the media layer resolves before loading.
    let avatarURL: URL?

    /// The latest message worth previewing, absent for rooms whose last event is not renderable.
    let preview: RoomPreviewMessage?

    /// When the latest event happened, used to timestamp and sort the row.
    let lastActivity: Date?

    /// Unread messages by the server's own count, regardless of push rules.
    let unreadMessages: Int

    /// Unread events the user's push rules asked to be notified about.
    let unreadNotifications: Int

    /// Unread events that mention the user directly.
    let unreadMentions: Int

    /// Whether the user pinned this room, which is what the Pinned section is built from.
    let isFavourite: Bool

    /// Whether the user pushed this room down, which keeps it out of the main section.
    let isLowPriority: Bool

    /// Whether this is a one to one chat rather than a group.
    let isDirect: Bool

    /// Whether the room has encryption enabled.
    let isEncrypted: Bool

    /// Whether a call is running in the room right now.
    let hasOngoingCall: Bool

    /// Whether the user manually flagged the room as unread, independently of the counters.
    let isMarkedUnread: Bool

    /// Whether the row deserves an unread badge at all.
    var hasUnread: Bool {
        isMarkedUnread || unreadMessages > 0 || unreadNotifications > 0
    }

    /// Whether the row deserves the louder mention treatment instead of a plain badge.
    var hasMentions: Bool {
        unreadMentions > 0
    }
}
