//
//  MessageSearchResultMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import MatrixRustSDK


/// Turns the SDK's search result stream into domain results and domain diffs.
enum MessageSearchResultMapper {

    /// Maps one batch of SDK updates, preserving order and indices so the batch can be applied
    /// atomically. Every SDK result maps to exactly one domain result, so no element is ever
    /// dropped and the indices carried by `insert`, `set` and `remove` stay valid.
    static func makeDiffs(
        from updates: [SearchServiceResultsUpdate],
        roomName    : (String) -> String?
    ) -> [CollectionDiff<MessageSearchResult>] {
        updates.map { update in
            switch update {
                case .append(let values): .append(values.map { makeResult(from: $0, roomName: roomName) })
                case .clear: .clear
                case .pushFront(let value): .pushFront(makeResult(from: value, roomName: roomName))
                case .pushBack(let value): .pushBack(makeResult(from: value, roomName: roomName))
                case .popFront: .popFront
                case .popBack: .popBack
                case .insert(let index, let value): .insert(index: Int(index), element: makeResult(from: value, roomName: roomName))
                case .set(let index, let value): .set(index: Int(index), element: makeResult(from: value, roomName: roomName))
                case .remove(let index): .remove(index: Int(index))
                case .truncate(let length): .truncate(length: Int(length))
                case .reset(let values): .reset(values.map { makeResult(from: $0, roomName: roomName) })
            }
        }
    }

    /// Maps a single tagged result. Only messages exist in this SDK release, so the switch is what
    /// will fail to compile the day another kind of entity joins the index.
    static func makeResult(
        from result: SearchServiceResult,
        roomName   : (String) -> String?
    ) -> MessageSearchResult {
        switch result {
            case .message(let roomID, let message): makeResult(from: message, roomID: roomID, roomName: roomName(roomID))
        }
    }

    /// Maps the SDK's message payload, resolving the snippet and the sender's display name.
    static func makeResult(
        from message: MatrixRustSDK.MessageSearchResult,
        roomID      : String,
        roomName    : String?
    ) -> MessageSearchResult {
        MessageSearchResult(
            roomID           : roomID,
            roomName         : roomName,
            eventID          : message.eventId,
            snippetText      : makeSnippet(from: message.content),
            sender           : message.sender,
            senderDisplayName: makeDisplayName(from: message.senderProfile),
            timestamp        : makeDate(from: message.timestamp)
        )
    }

    /// Flattens an event's content into the single line a result row prints.
    static func makeSnippet(from content: TimelineItemContent) -> String {
        switch content {
            case .msgLike(let content): makeSnippet(from: content.kind)
            case .callInvite, .rtcNotification: "Call"
            case .roomMembership: "Membership change"
            case .profileChange: "Profile change"
            case .state: "Room settings changed"
            case .failedToParseMessageLike, .failedToParseState: "Unsupported event"
        }
    }

    private static func makeSnippet(from kind: MsgLikeKind) -> String {
        switch kind {
            case .message(let content): content.body
            case .sticker(let body, _, _): body
            case .poll(let question, _, _, _, _, _, _): question
            case .redacted: "Message deleted"
            case .unableToDecrypt: "Encrypted message"
            case .liveLocation: "Live location"
            case .other: "Message"
        }
    }

    private static func makeDisplayName(from profile: ProfileDetails) -> String? {
        switch profile {
            case .ready(let displayName, _, _, _, _): displayName
            case .unavailable, .pending, .error: nil
        }
    }

    private static func makeDate(from timestamp: Timestamp) -> Date {
        Date(timeIntervalSince1970: Double(timestamp) / 1000)
    }
}
