//
//  RoomPreviewMessage.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// The single line of text a chat row shows underneath the room name.
struct RoomPreviewMessage: Equatable {

    /// Who sent it, already resolved to a display name whenever the homeserver knew one.
    let senderName: String

    /// What to show, collapsed to one line and summarized by kind for media events.
    let text: String

    /// Whether the signed in account sent it, so the row can prefix it with "You".
    let isOwn: Bool
}
