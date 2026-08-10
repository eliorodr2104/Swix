//
//  NotificationItem.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Everything needed to draw one notification, resolved and decrypted already.
///
/// This is the shape a Notification Service Extension would hand to `UNMutableNotificationContent`,
/// which is why it carries display names and avatars rather than raw identifiers alone: once the
/// extension has answered, there is no second chance to look anything up.
struct NotificationItem: Equatable, Identifiable {

    /// The room the notifying event belongs to.
    let roomID: String

    /// The notifying event. Absent for invites, which are announced by state rather than by an
    /// event Swix ever gets to address.
    let eventID: String?

    /// The Matrix ID of whoever caused the notification.
    let senderID: String

    /// The sender's display name, already falling back to the Matrix ID when the profile is unknown.
    let senderDisplayName: String

    /// The sender's avatar as an `mxc://` URI, to be resolved through the media services.
    let senderAvatarURL: String?

    /// The room's display name, ready to be used as the notification title.
    let roomDisplayName: String

    /// The room's avatar as an `mxc://` URI.
    let roomAvatarURL: String?

    /// The notification text, extracted from the event content.
    let body: String

    /// Whether the push rules asked for a sound rather than a silent delivery.
    let isNoisy: Bool

    /// Whether the event mentions the current user, which UI can promote over a plain message.
    let hasMention: Bool

    /// The thread this event belongs to, so a tap can open the thread instead of the room.
    let threadID: String?

    /// Whether this is an invitation to join the room rather than a message inside it.
    let isInvite: Bool

    /// Notifications are identified by their event, and invites by the room they invite to.
    var id: String {
        eventID ?? roomID
    }

    init(
        roomID           : String,
        eventID          : String?,
        senderID         : String,
        senderDisplayName: String,
        senderAvatarURL  : String?,
        roomDisplayName  : String,
        roomAvatarURL    : String?,
        body             : String,
        isNoisy          : Bool,
        hasMention       : Bool,
        threadID         : String?,
        isInvite         : Bool
    ) {
        self.roomID            = roomID
        self.eventID           = eventID
        self.senderID          = senderID
        self.senderDisplayName = senderDisplayName
        self.senderAvatarURL   = senderAvatarURL
        self.roomDisplayName   = roomDisplayName
        self.roomAvatarURL     = roomAvatarURL
        self.body              = body
        self.isNoisy           = isNoisy
        self.hasMention        = hasMention
        self.threadID          = threadID
        self.isInvite          = isInvite
    }
}
