//
//  ThreadEntryMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import MatrixRustSDK


/// Turns one SDK thread list item into the row the thread list renders.
///
/// The SDK fetches the sender profiles and parses the event content while building the item, so the
/// mapping is synchronous and nothing here hides a round trip to the homeserver.
enum ThreadEntryMapper {

    /// Maps one thread.
    ///
    /// The subscription is left `.unknown` on purpose: the list says nothing about it, and asking
    /// per row would mean one request per thread on a screen that shows dozens of them.
    static func makeEntry(from item: ThreadListItem) -> ThreadEntry {
        ThreadEntry(
            rootEventID         : item.rootEvent.eventId,
            rootPreviewText     : makePreviewText(from: item.rootEvent),
            senderName          : makeSenderName(from: item.rootEvent),
            isOwn               : item.rootEvent.isOwn,
            rootTimestamp       : makeDate(from: item.rootEvent.timestamp),
            lastReplyPreviewText: item.latestEvent.map { makePreviewText(from: $0) },
            lastReplySenderName : item.latestEvent.map { makeSenderName(from: $0) },
            lastReplyTimestamp  : item.latestEvent.map { makeDate(from: $0.timestamp) },
            replyCount          : Int(item.numReplies),
            subscription        : .unknown
        )
    }

    /// Converts the SDK's milliseconds since the epoch into a date.
    static func makeDate(from timestamp: Timestamp) -> Date {
        Date(timeIntervalSince1970: Double(timestamp) / 1000)
    }

    private static let placeholderPreviewText = "No message"

    /// Prefers the profile's own display name, falling back to the raw user id when the profile
    /// never resolved or the account simply never set one.
    private static func makeSenderName(from event: ThreadListItemEvent) -> String {
        switch event.senderProfile {
            case .ready(let displayName, _, _, _, _): displayName ?? event.sender
            case .unavailable, .pending, .error: event.sender
        }
    }

    /// The content is optional on the SDK's item, and a thread whose root it could not parse still
    /// has to be reachable: a row with a placeholder line is far better than a thread the user
    /// cannot open at all.
    private static func makePreviewText(from event: ThreadListItemEvent) -> String {
        guard
            let content = event.content,
            let text = makeText(from: content),
            !text.isEmpty
        else {
            return placeholderPreviewText
        }

        return text
    }

    /// Only message like content and calls say anything worth a line; a membership change or a state
    /// event as a thread root is noise, so it falls back to the placeholder.
    ///
    /// RoomList's `LatestEventMapper` answers this same question for `LatestEventValue`, a type that
    /// shares none of this input: one duplicated switch is cheaper than a dependency between two
    /// features that would then have to agree on their wording forever.
    private static func makeText(from content: TimelineItemContent) -> String? {
        switch content {
            case .msgLike(let content): makeText(from: content.kind)
            case .callInvite, .rtcNotification: "Call"
            case .roomMembership, .profileChange, .state: nil
            case .failedToParseMessageLike, .failedToParseState: nil
        }
    }

    /// Picks the right one line summary for each kind of message like event.
    private static func makeText(from kind: MsgLikeKind) -> String? {
        switch kind {
            case .message(let content): makeText(from: content)
            case .sticker(let body, _, _): collapse(body)
            case .poll(let question, _, _, _, _, _, _): collapse(question)
            case .redacted: "Message deleted"
            case .unableToDecrypt: "Encrypted message"
            case .liveLocation: "Live location"
            case .other: nil
        }
    }

    /// Media keeps a label rather than its body, because the body of an attachment is the file name
    /// on disk and a thread row reads far better with "Photo" than with "IMG_4821.HEIC".
    private static func makeText(from content: MessageContent) -> String {
        switch content.msgType {
            case .text, .notice, .emote, .other: collapse(content.body)
            case .image: "Photo"
            case .video: "Video"
            case .audio: "Audio message"
            case .file: "File"
            case .gallery: "Album"
            case .location: "Location"
        }
    }

    /// Flattens a multi line body into one line, which is all a thread row has room for.
    private static func collapse(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
