//
//  LatestEventMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import MatrixRustSDK


/// Turns the SDK's `LatestEventValue` into the one line preview and the timestamp a chat row needs.
enum LatestEventMapper {

    /// Builds the preview line, or nil when the latest event is not something worth previewing
    /// such as a membership change or a state event.
    static func makePreview(from value: LatestEventValue) -> RoomPreviewMessage? {
        switch value {
            case .none:
                return nil

            case .remote(_, let sender, let isOwn, let profile, let content):
                guard let text = makeText(from: content) else {
                    return nil
                }

                return RoomPreviewMessage(
                    senderName: makeSenderName(from: profile, fallback: sender),
                    text      : text,
                    isOwn     : isOwn
                )

            case .local(_, let sender, let profile, let content, _):
                guard let text = makeText(from: content) else {
                    return nil
                }

                return RoomPreviewMessage(
                    senderName: makeSenderName(from: profile, fallback: sender),
                    text      : text,
                    isOwn     : true
                )

            case .remoteInvite(_, let inviter, let inviterProfile):
                let senderName = makeSenderName(from: inviterProfile, fallback: inviter ?? unknownSenderName)

                return RoomPreviewMessage(
                    senderName: senderName,
                    text      : "Invited you to chat",
                    isOwn     : false
                )
        }
    }

    /// When the latest event happened, which is what the row timestamps and the list sorts on.
    static func makeLastActivity(from value: LatestEventValue) -> Date? {
        switch value {
            case .none: nil
            case .remote(let timestamp, _, _, _, _): makeDate(from: timestamp)
            case .remoteInvite(let timestamp, _, _): makeDate(from: timestamp)
            case .local(let timestamp, _, _, _, _): makeDate(from: timestamp)
        }
    }

    private static let unknownSenderName = "Someone"

    /// Converts the SDK's millisecond epoch timestamp into a `Date`, the unit the rest of Core
    /// works in.
    private static func makeDate(from timestamp: Timestamp) -> Date {
        Date(timeIntervalSince1970: Double(timestamp) / 1000)
    }

    /// Prefers the profile's own display name, falling back to the raw sender id when the profile
    /// never resolved or the user never set one.
    private static func makeSenderName(
        from profile: ProfileDetails,
        fallback    : String
    ) -> String {

        switch profile {
            case .ready(let displayName, _, _, _, _): displayName ?? fallback
            case .unavailable, .pending, .error: fallback
        }
    }

    /// Only message-like content and calls are worth a preview; membership changes and state
    /// events would just clutter the list with noise nobody reads.
    private static func makeText(from content: TimelineItemContent) -> String? {
        switch content {
            case .msgLike(let content): makeText(from: content.kind)
            case .callInvite, .rtcNotification: "Call"
            case .roomMembership, .profileChange, .state: nil
            case .failedToParseMessageLike, .failedToParseState: nil
        }
    }

    /// Picks the right one line summary for each kind of message-like event.
    private static func makeText(from kind: MsgLikeKind) -> String? {
        switch kind {
            case .message(let content): makeText(from: content)
            case .sticker(let body, _, _): collapse(body).isEmpty ? "Sticker" : collapse(body)
            case .poll(let question, _, _, _, _, _, _): collapse(question)
            case .redacted: "Message deleted"
            case .unableToDecrypt: "Encrypted message"
            case .liveLocation: "Live location"
            case .other: nil
        }
    }

    /// Media keeps a label rather than its body, because the body of an attachment is the file
    /// name on disk and a chat list reads far better with "Photo" than with "IMG_4821.HEIC".
    private static func makeText(from content: MessageContent) -> String {
        switch content.msgType {
            case .text, .notice, .emote: collapse(content.body)
            case .image: "Photo"
            case .video: "Video"
            case .audio: "Audio message"
            case .file: "File"
            case .gallery: "Album"
            case .location: "Location"
            case .other: collapse(content.body)
        }
    }

    /// Flattens a multi line body into one line, which is all a chat row has room for.
    private static func collapse(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
