//
//  TimelineEntryMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import MatrixRustSDK


/// Turns one SDK timeline item into the row the UI renders.
///
/// Everything needed is already inside the item, so the mapping is synchronous: `asEvent()`,
/// `asVirtual()` and `uniqueId()` are plain reads over the FFI, with no round trip to the
/// homeserver hiding behind them.
enum TimelineEntryMapper {

    /// Maps one row.
    ///
    /// `ownUserID` is what decides whether a reaction pill is highlighted and which poll options
    /// count as the user's own vote; the SDK reports both as plain lists of user ids and leaves the
    /// comparison to the client.
    static func makeEntry(
        from item: TimelineItem,
        ownUserID: String?
    ) -> TimelineEntry {

        let id = item.uniqueId().id

        if let event = item.asEvent() {
            return makeEntry(
                from     : event,
                id       : id,
                ownUserID: ownUserID
            )
        }

        if let virtual = item.asVirtual() {
            return makeEntry(from: virtual, id: id)
        }

        // The two accessors are independent optionals, so nothing in the type system rules out an
        // item that is neither. It cannot happen today, and it still has to render as something.
        return .notice(
            TimelineNotice(
                id       : id,
                text     : unknownRowText,
                timestamp: nil
            )
        )
    }

    /// The sender's display name as the SDK resolved it, nil while the profile is still loading or
    /// when the account simply never set one.
    static func makeSenderDisplayName(from profile: ProfileDetails) -> String? {
        switch profile {
            case .ready(let displayName, _, _, _, _): displayName
            case .unavailable, .pending, .error: nil
        }
    }

    /// Maps a domain identifier back into the SDK's own, which is how every operation that acts on
    /// an event names it, local echoes included.
    static func makeItemID(from identifier: EventIdentifier) -> EventOrTransactionId {
        switch identifier {
            case .event(let eventID): .eventId(eventId: eventID)
            case .transaction(let transactionID): .transactionId(transactionId: transactionID)
        }
    }

    /// Converts the SDK's milliseconds since the epoch into a date.
    static func makeDate(from timestamp: Timestamp) -> Date {
        Date(timeIntervalSince1970: Double(timestamp) / 1000)
    }

    private static let unknownRowText = "Unsupported event"

    private static let undecryptableBody = "Waiting for this message"

    private static let liveLocationBody = "Live location"

    private static func makeEntry(
        from event: EventTimelineItem,
        id        : String,
        ownUserID : String?
    ) -> TimelineEntry {

        guard case .msgLike(let content) = event.content else {
            return .notice(TimelineNoticeMapper.makeNotice(from: event, id: id))
        }

        switch content.kind {
            case .message(let message):
                return .message(
                    makeMessage(
                        body           : makeBody(from: message),
                        mediaKind      : makeMediaKind(from: message.msgType),
                        isEdited       : message.isEdited,
                        isUndecryptable: false,
                        content        : content,
                        event          : event,
                        id             : id,
                        ownUserID      : ownUserID
                    )
                )

            case .sticker(let body, _, _):
                return .message(
                    makeMessage(
                        body           : body,
                        mediaKind      : .sticker,
                        isEdited       : false,
                        isUndecryptable: false,
                        content        : content,
                        event          : event,
                        id             : id,
                        ownUserID      : ownUserID
                    )
                )

            case .liveLocation(let location):
                return .message(
                    makeMessage(
                        body           : location.description ?? liveLocationBody,
                        mediaKind      : .location,
                        isEdited       : false,
                        isUndecryptable: false,
                        content        : content,
                        event          : event,
                        id             : id,
                        ownUserID      : ownUserID
                    )
                )

            case .unableToDecrypt:
                return .message(
                    makeMessage(
                        body           : undecryptableBody,
                        mediaKind      : nil,
                        isEdited       : false,
                        isUndecryptable: true,
                        content        : content,
                        event          : event,
                        id             : id,
                        ownUserID      : ownUserID
                    )
                )

            case .poll(
                let question,
                let kind,
                let maxSelections,
                let answers,
                let votes,
                let endTime,
                let hasBeenEdited
            ):
                return .poll(
                    makePoll(
                        question     : question,
                        kind         : kind,
                        maxSelections: maxSelections,
                        answers      : answers,
                        votes        : votes,
                        endTime      : endTime,
                        isEdited     : hasBeenEdited,
                        content      : content,
                        event        : event,
                        id           : id,
                        ownUserID    : ownUserID
                    )
                )

            case .redacted, .other:
                return .notice(TimelineNoticeMapper.makeNotice(from: event, id: id))
        }
    }

    private static func makeEntry(
        from virtual: VirtualTimelineItem,
        id          : String
    ) -> TimelineEntry {

        switch virtual {
            case .dateDivider(let timestamp): .dateSeparator(id: id, date: makeDate(from: timestamp))
            case .readMarker: .readMarker(id: id)
            case .timelineStart: .timelineStart(id: id)
        }
    }

    private static func makeMessage(
        body           : String,
        mediaKind      : MessageMediaKind?,
        isEdited       : Bool,
        isUndecryptable: Bool,
        content        : MsgLikeContent,
        event          : EventTimelineItem,
        id             : String,
        ownUserID      : String?
    ) -> MessageEntry {

        MessageEntry(
            id               : id,
            eventIdentifier  : makeIdentifier(from: event.eventOrTransactionId),
            sender           : event.sender,
            senderDisplayName: makeSenderDisplayName(from: event.senderProfile),
            body             : body,
            timestamp        : makeDate(from: event.timestamp),
            isOwn            : event.isOwn,
            isEdited         : isEdited,
            isEditable       : event.isEditable,
            sendState        : makeSendState(from: event.localSendState),
            mediaKind        : mediaKind,
            reactions        : makeReactions(from: content.reactions, ownUserID: ownUserID),
            readReceipts     : makeReceipts(from: event.readReceipts),
            isUndecryptable  : isUndecryptable
        )
    }

    private static func makePoll(
        question     : String,
        kind         : PollKind,
        maxSelections: UInt64,
        answers      : [PollAnswer],
        votes        : [String: [String]],
        endTime      : Timestamp?,
        isEdited     : Bool,
        content      : MsgLikeContent,
        event        : EventTimelineItem,
        id           : String,
        ownUserID    : String?
    ) -> PollEntry {

        PollEntry(
            id               : id,
            eventIdentifier  : makeIdentifier(from: event.eventOrTransactionId),
            sender           : event.sender,
            senderDisplayName: makeSenderDisplayName(from: event.senderProfile),
            question         : question,
            answers          : makeAnswers(from: answers, votes: votes, ownUserID: ownUserID),
            kind             : makeVisibility(from: kind),
            maxSelections    : Int(maxSelections),
            timestamp        : makeDate(from: event.timestamp),
            isOwn            : event.isOwn,
            isEdited         : isEdited,
            endDate          : endTime.map { makeDate(from: $0) },
            sendState        : makeSendState(from: event.localSendState),
            reactions        : makeReactions(from: content.reactions, ownUserID: ownUserID),
            readReceipts     : makeReceipts(from: event.readReceipts)
        )
    }

    private static func makeAnswers(
        from answers: [PollAnswer],
        votes       : [String: [String]],
        ownUserID   : String?
    ) -> [PollAnswerEntry] {

        answers.map { answer in
            let voters = votes[answer.id] ?? []

            return PollAnswerEntry(
                id       : answer.id,
                text     : answer.text,
                voteCount: voters.count,
                isOwnVote: ownUserID.map { voters.contains($0) } ?? false
            )
        }
    }

    private static func makeVisibility(from kind: PollKind) -> PollVisibility {
        switch kind {
            case .disclosed: .disclosed
            case .undisclosed: .undisclosed
        }
    }

    private static func makeIdentifier(from id: EventOrTransactionId) -> EventIdentifier {
        switch id {
            case .eventId(let eventID): .event(eventID)
            case .transactionId(let transactionID): .transaction(transactionID)
        }
    }

    /// A remote event has no send state at all, which is exactly what an absent one means here.
    private static func makeSendState(from state: EventSendState?) -> TimelineSendState? {
        guard let state else {
            return nil
        }

        switch state {
            case .notSentYet: return .sending
            case .sent(let eventID): return .sent(eventID: eventID)

            case .sendingFailed(let error, let isRecoverable):
                return .failed(
                    reason       : SendQueueUpdateMapper.makeReason(from: error),
                    isRecoverable: isRecoverable
                )
        }
    }

    private static func makeReactions(
        from reactions: [Reaction],
        ownUserID     : String?
    ) -> [ReactionInfo] {

        reactions.map { reaction in
            let senderIDs = reaction.senders.map(\.senderId)

            return ReactionInfo(
                key      : reaction.key,
                senderIDs: senderIDs,
                isOwn    : ownUserID.map { senderIDs.contains($0) } ?? false
            )
        }
    }

    /// The SDK keys receipts by user id, and a dictionary has no order: sorting by user id is what
    /// keeps two mappings of the same event equal, so an unchanged row does not redraw.
    private static func makeReceipts(from receipts: [String: Receipt]) -> [ReceiptInfo] {
        receipts
            .sorted { $0.key < $1.key }
            .map { userID, receipt in
                ReceiptInfo(
                    userID   : userID,
                    eventID  : nil,
                    timestamp: receipt.timestamp.map { makeDate(from: $0) }
                )
            }
    }

    private static func makeMediaKind(from msgType: MessageType) -> MessageMediaKind? {
        switch msgType {
            case .image: .image
            case .video: .video
            case .audio(let content): content.voice == nil ? .audio : .voice
            case .file: .file
            case .gallery: .gallery
            case .location: .location
            case .emote, .notice, .text, .other: nil
        }
    }

    /// The SDK already collapses an attachment's caption or filename into `body`, so the only gap
    /// left to fill is an attachment that arrived with neither, which some bridges do send.
    private static func makeBody(from content: MessageContent) -> String {
        guard content.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return content.body
        }

        return makeFallbackBody(for: content.msgType)
    }

    private static func makeFallbackBody(for msgType: MessageType) -> String {
        switch msgType {
            case .image(let content): content.filename
            case .video(let content): content.filename
            case .audio(let content): content.filename
            case .file(let content): content.filename
            case .gallery(let content): content.body
            case .location(let content): content.body
            case .emote(let content): content.body
            case .notice(let content): content.body
            case .text(let content): content.body
            case .other(_, let body): body
        }
    }
}
