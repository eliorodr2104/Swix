//
//  NotificationItemMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import os


/// Flattens the SDK's resolved notification into the single struct a notification UI can draw.
///
/// SDK types are spelled with their module here because Core declares its own `NotificationItem`:
/// the qualification keeps the two apart for a reader, not only for the compiler.
enum NotificationItemMapper {

    /// Maps a fetch result, returning nil for the outcomes that must not become a notification:
    /// events the push rules filtered out, events that were redacted, and events the server lost.
    static func makeNotificationItem(
        from status: MatrixRustSDK.NotificationStatus,
        roomID     : String,
        eventID    : String?
    ) -> NotificationItem? {
        switch status {
            case .event(let item): makeNotificationItem(from: item, roomID: roomID, eventID: eventID)
            case .eventNotFound, .eventFilteredOut, .eventRedacted: nil
        }
    }

    /// Maps a resolved notification. `eventID` comes from the request when there was one, since an
    /// invite carries no event of its own to read an identifier from.
    static func makeNotificationItem(
        from item: MatrixRustSDK.NotificationItem,
        roomID   : String,
        eventID  : String? = nil
    ) -> NotificationItem {
        let timelineEvent = makeTimelineEvent(from: item.event)

        return NotificationItem(
            roomID           : roomID,
            eventID          : eventID ?? timelineEvent?.eventId(),
            senderID         : makeSenderID(from: item.event) ?? "",
            senderDisplayName: item.senderInfo.displayName ?? makeSenderID(from: item.event) ?? "",
            senderAvatarURL  : item.senderInfo.avatarUrl,
            roomDisplayName  : item.roomInfo.displayName,
            roomAvatarURL    : item.roomInfo.avatarUrl,
            body             : makeBody(from: item.event),
            isNoisy          : item.isNoisy ?? makeIsNoisy(from: item.actions),
            hasMention       : item.hasMention ?? false,
            threadID         : item.threadId ?? timelineEvent?.threadRootEventId(),
            isInvite         : timelineEvent == nil
        )
    }

    private static func makeTimelineEvent(from event: NotificationEvent) -> TimelineEvent? {
        switch event {
            case .timeline(let event): event
            case .invite: nil
        }
    }

    private static func makeSenderID(from event: NotificationEvent) -> String? {
        switch event {
            case .timeline(let event): event.senderId()
            case .invite(let sender): sender
        }
    }

    /// The homeserver only tells us whether a notification is noisy when it could build a push
    /// context, so the push actions are read directly when it could not.
    private static func makeIsNoisy(from actions: [Action]?) -> Bool {
        guard let actions else {
            return false
        }

        return actions.contains { action in
            guard case .setTweak(let tweak) = action, case .sound = tweak else {
                return false
            }

            return true
        }
    }

    private static func makeBody(from event: NotificationEvent) -> String {
        switch event {
            case .invite: "Invited you to chat"
            case .timeline(let event): makeBody(from: event)
        }
    }

    private static func makeBody(from event: TimelineEvent) -> String {
        do {
            switch try event.content() {
                case .messageLike(let content): return makeBody(from: content)
                case .state: return "Updated the room"
            }
        } catch {
            Log.notifications.error("Notification content could not be read: \(String(reflecting: error), privacy: .public)")

            return "New message"
        }
    }

    private static func makeBody(from content: MessageLikeEventContent) -> String {
        switch content {
            case .roomMessage(let messageType, _): makeBody(from: messageType)
            case .poll(let question): question
            case .roomEncrypted: "Encrypted message"
            case .reactionContent: "Reacted to a message"
            case .roomRedaction: "Removed a message"
            case .sticker: "Sent a sticker"
            case .beacon: "Shared their live location"
            case .callInvite, .callAnswer, .callHangup, .callCandidates, .rtcNotification: "Call"
            case .keyVerificationReady,
                 .keyVerificationStart,
                 .keyVerificationCancel,
                 .keyVerificationAccept,
                 .keyVerificationKey,
                 .keyVerificationMac,
                 .keyVerificationDone: "Verification request"
        }
    }

    /// Captions win over filenames because a sender who bothered to write one meant it to be read.
    private static func makeBody(from messageType: MessageType) -> String {
        switch messageType {
            case .text(let content): content.body
            case .notice(let content): content.body
            case .emote(let content): content.body
            case .gallery(let content): content.body
            case .location(let content): content.body
            case .image(let content): content.caption ?? content.filename
            case .video(let content): content.caption ?? content.filename
            case .audio(let content): content.caption ?? content.filename
            case .file(let content): content.caption ?? content.filename
            case .other(_, let body): body
        }
    }
}
