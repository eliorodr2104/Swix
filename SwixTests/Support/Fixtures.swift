//
//  Fixtures.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import MatrixRustSDK
@testable import Swix


/// Builders for the value types that show up in every suite's arrange step, each with a default
/// that is already a valid, self-consistent instance.
///
/// A test only ever names the field its assertion cares about; every other field is whatever
/// default reads best here, which is what keeps the suites free of boilerplate that has nothing
/// to do with what they are checking.
enum Fixtures {

    /// A session as it would be read back from the keychain: a real access token, a real device,
    /// native sliding sync, password login by default (`oauthData` nil).
    static func persistedSession(
        accessToken       : String = "access-token",
        refreshToken      : String? = nil,
        userID            : String = "@alice:example.org",
        deviceID          : String = "DEVICE1",
        homeserverURL     : String = "https://example.org",
        oauthData         : String? = nil,
        slidingSyncVersion: String = "native"
    ) -> PersistedSession {

        PersistedSession(
            accessToken       : accessToken,
            refreshToken      : refreshToken,
            userID            : userID,
            deviceID          : deviceID,
            homeserverURL     : homeserverURL,
            oauthData         : oauthData,
            slidingSyncVersion: slidingSyncVersion
        )
    }

    /// The store identity of an account that already exists, as opposed to
    /// `SessionStoreIdentity.makeProvisional()` which mints one for a login in progress.
    static func storeIdentity(
        directoryIdentifier: String = "directory-identifier",
        storePassphrase    : String = "store-passphrase"
    ) -> SessionStoreIdentity {

        SessionStoreIdentity(
            directoryIdentifier: directoryIdentifier,
            storePassphrase    : storePassphrase
        )
    }

    /// What a homeserver advertises, defaulted to a plain password-only, sliding-sync-capable
    /// server since that is the common case every flow selection test starts from.
    static func loginMethods(
        url               : String = "https://example.org",
        supportsPassword  : Bool = true,
        supportsOAuth     : Bool = false,
        supportsSSO       : Bool = false,
        slidingSyncVersion: SlidingSyncSupport = .native
    ) -> HomeserverLoginMethods {

        HomeserverLoginMethods(
            url               : url,
            supportsPassword  : supportsPassword,
            supportsOAuth     : supportsOAuth,
            supportsSSO       : supportsSSO,
            slidingSyncVersion: slidingSyncVersion
        )
    }

    /// The signed-in account as the rest of the app sees it, secrets already stripped.
    static func userSession(
        userID       : String = "@alice:example.org",
        deviceID     : String = "DEVICE1",
        homeserverURL: String = "https://example.org",
        usedOAuth    : Bool = false
    ) -> UserSession {

        UserSession(
            userID       : userID,
            deviceID     : deviceID,
            homeserverURL: homeserverURL,
            usedOAuth    : usedOAuth
        )
    }

    /// A normalized SDK error, defaulted to `.unknown` since most failure tests only care about
    /// the kind they deliberately override.
    static func sdkErrorInfo(
        kind   : SDKErrorKind = .unknown,
        message: String = "something went wrong",
        details: String? = nil
    ) -> SDKErrorInfo {

        SDKErrorInfo(
            kind   : kind,
            message: message,
            details: details
        )
    }

    /// A syntactically valid, non-empty pair of credentials.
    static func passwordCredentials(
        username: String = "alice",
        password: String = "hunter2"
    ) -> PasswordCredentials {

        PasswordCredentials(
            username: username,
            password: password
        )
    }

    /// One chat list row: an ordinary, non-favourite, unencrypted group room with nothing unread,
    /// so a diff application or partition test only has to override the field it is checking.
    static func roomSummary(
        id                 : String = "!room:example.org",
        name               : String = "Room",
        avatarURL          : URL? = nil,
        preview            : RoomPreviewMessage? = nil,
        lastActivity       : Date? = nil,
        unreadMessages     : Int = 0,
        unreadNotifications: Int = 0,
        unreadMentions     : Int = 0,
        isFavourite        : Bool = false,
        isLowPriority      : Bool = false,
        isDirect           : Bool = false,
        isEncrypted        : Bool = false,
        hasOngoingCall     : Bool = false,
        isMarkedUnread     : Bool = false
    ) -> RoomSummary {

        RoomSummary(
            id                 : id,
            name               : name,
            avatarURL          : avatarURL,
            preview            : preview,
            lastActivity       : lastActivity,
            unreadMessages     : unreadMessages,
            unreadNotifications: unreadNotifications,
            unreadMentions     : unreadMentions,
            isFavourite        : isFavourite,
            isLowPriority      : isLowPriority,
            isDirect           : isDirect,
            isEncrypted        : isEncrypted,
            hasOngoingCall     : hasOngoingCall,
            isMarkedUnread     : isMarkedUnread
        )
    }

    /// A plain text message bubble from someone else, already sent, which is the baseline every
    /// send queue reconciliation or reaction test starts from before overriding one field.
    static func messageEntry(
        id               : String = "item-1",
        eventIdentifier  : EventIdentifier = .event("$event1"),
        sender           : String = "@bob:example.org",
        senderDisplayName: String? = "Bob",
        body             : String = "Hello",
        timestamp        : Date = Date(timeIntervalSince1970: 0),
        isOwn            : Bool = false,
        isEdited         : Bool = false,
        isEditable       : Bool = false,
        sendState        : TimelineSendState? = nil,
        mediaKind        : MessageMediaKind? = nil,
        reactions        : [ReactionInfo] = [],
        readReceipts     : [ReceiptInfo] = [],
        isUndecryptable  : Bool = false
    ) -> MessageEntry {

        MessageEntry(
            id               : id,
            eventIdentifier  : eventIdentifier,
            sender           : sender,
            senderDisplayName: senderDisplayName,
            body             : body,
            timestamp        : timestamp,
            isOwn            : isOwn,
            isEdited         : isEdited,
            isEditable       : isEditable,
            sendState        : sendState,
            mediaKind        : mediaKind,
            reactions        : reactions,
            readReceipts     : readReceipts,
            isUndecryptable  : isUndecryptable
        )
    }

    /// A `.message` row wrapping `messageEntry(...)`, for tests that only care about the row's
    /// place in the timeline and not the bubble underneath it.
    static func timelineMessage(
        id               : String = "item-1",
        eventIdentifier  : EventIdentifier = .event("$event1"),
        isOwn            : Bool = false,
        sendState        : TimelineSendState? = nil,
        reactions        : [ReactionInfo] = []
    ) -> TimelineEntry {

        .message(
            messageEntry(
                id             : id,
                eventIdentifier: eventIdentifier,
                isOwn          : isOwn,
                sendState      : sendState,
                reactions      : reactions
            )
        )
    }

    /// One poll option with its tally already resolved.
    static func pollAnswerEntry(
        id       : String = "answer-1",
        text     : String = "Red",
        voteCount: Int = 0,
        isOwnVote: Bool = false
    ) -> PollAnswerEntry {

        PollAnswerEntry(
            id       : id,
            text     : text,
            voteCount: voteCount,
            isOwnVote: isOwnVote
        )
    }

    /// An open, disclosed, single choice poll with two options and nobody's voted yet, which is
    /// the baseline a vote or an end poll test starts from before overriding one field.
    static func pollEntry(
        id               : String = "poll-1",
        eventIdentifier  : EventIdentifier = .event("$poll1"),
        sender           : String = "@bob:example.org",
        senderDisplayName: String? = "Bob",
        question         : String = "Favourite color?",
        answers          : [PollAnswerEntry] = [
            Fixtures.pollAnswerEntry(id: "answer-1", text: "Red"),
            Fixtures.pollAnswerEntry(id: "answer-2", text: "Blue")
        ],
        kind             : PollVisibility = .disclosed,
        maxSelections    : Int = 1,
        timestamp        : Date = Date(timeIntervalSince1970: 0),
        isOwn            : Bool = false,
        isEdited         : Bool = false,
        endDate          : Date? = nil,
        sendState        : TimelineSendState? = nil,
        reactions        : [ReactionInfo] = [],
        readReceipts     : [ReceiptInfo] = []
    ) -> PollEntry {

        PollEntry(
            id               : id,
            eventIdentifier  : eventIdentifier,
            sender           : sender,
            senderDisplayName: senderDisplayName,
            question         : question,
            answers          : answers,
            kind             : kind,
            maxSelections    : maxSelections,
            timestamp        : timestamp,
            isOwn            : isOwn,
            isEdited         : isEdited,
            endDate          : endDate,
            sendState        : sendState,
            reactions        : reactions,
            readReceipts     : readReceipts
        )
    }

    /// A `.poll` row wrapping `pollEntry(...)`.
    static func timelinePoll(
        id             : String = "poll-1",
        eventIdentifier: EventIdentifier = .event("$poll1"),
        isOwn          : Bool = false,
        endDate        : Date? = nil
    ) -> TimelineEntry {

        .poll(
            pollEntry(
                id             : id,
                eventIdentifier: eventIdentifier,
                isOwn          : isOwn,
                endDate        : endDate
            )
        )
    }

    /// One emoji reaction, defaulted to a single sender who is not the signed in account.
    static func reactionInfo(
        key      : String = "👍",
        senderIDs: [String] = ["@carol:example.org"],
        isOwn    : Bool = false
    ) -> ReactionInfo {

        ReactionInfo(
            key      : key,
            senderIDs: senderIDs,
            isOwn    : isOwn
        )
    }

    /// A read receipt read off the event that carries it, so `eventID` stays nil the way
    /// `TimelineEntryMapper` produces it.
    static func receiptInfo(
        userID   : String = "@carol:example.org",
        eventID  : String? = nil,
        timestamp: Date? = Date(timeIntervalSince1970: 0)
    ) -> ReceiptInfo {

        ReceiptInfo(
            userID   : userID,
            eventID  : eventID,
            timestamp: timestamp
        )
    }

    /// An SDK message-like event, defaulted to a plain text message from someone else with no
    /// reactions or local send state: the shape `TimelineEntryMapper` turns into a `.message` row
    /// when nothing else is going on.
    ///
    /// `lazyProvider` is a `noHandle` fake: `TimelineEntryMapper` never calls any of its methods,
    /// so it only has to exist, not do anything.
    static func eventTimelineItem(
        eventOrTransactionId: EventOrTransactionId = .eventId(eventId: "$event1"),
        sender              : String = "@bob:example.org",
        senderProfile       : ProfileDetails = .ready(
            displayName         : "Bob",
            displayNameAmbiguous: false,
            avatarUrl           : nil,
            status              : nil,
            call                : nil
        ),
        isOwn         : Bool = false,
        isEditable    : Bool = false,
        content       : TimelineItemContent = .msgLike(content: Fixtures.textMsgLikeContent()),
        timestamp     : Timestamp = 0,
        localSendState: EventSendState? = nil,
        readReceipts  : [String: Receipt] = [:]
    ) -> EventTimelineItem {

        EventTimelineItem(
            isRemote            : true,
            eventOrTransactionId: eventOrTransactionId,
            sender              : sender,
            senderProfile       : senderProfile,
            forwarder           : nil,
            forwarderProfile    : nil,
            isOwn               : isOwn,
            isEditable          : isEditable,
            content             : content,
            eventTypeRaw        : "m.room.message",
            timestamp           : timestamp,
            localSendState      : localSendState,
            localCreatedAt      : nil,
            readReceipts        : readReceipts,
            origin              : nil,
            canBeRepliedTo      : true,
            lazyProvider        : LazyTimelineItemProvider(noHandle: .init())
        )
    }

    /// An `m.room.message` text event wrapped as `MsgLikeContent`, with whatever reactions the
    /// test wants `TimelineEntryMapper` to fold into the row.
    static func textMsgLikeContent(
        body     : String = "Hello",
        reactions: [Reaction] = []
    ) -> MsgLikeContent {

        MsgLikeContent(
            kind: .message(
                content: MessageContent(
                    msgType : .text(content: TextMessageContent(body: body, formatted: nil)),
                    body    : body,
                    isEdited: false,
                    mentions: nil
                )
            ),
            reactions    : reactions,
            inReplyTo    : nil,
            threadRoot   : nil,
            threadSummary: nil
        )
    }

    /// An `m.poll.start` event wrapped as `MsgLikeContent`, tally and visibility already set, which
    /// is what `TimelineEntryMapper` turns into a `PollEntry`.
    static func pollMsgLikeContent(
        question     : String = "Favourite color?",
        kind         : PollKind = .disclosed,
        maxSelections: UInt64 = 1,
        answers      : [PollAnswer] = [
            PollAnswer(id: "answer-1", text: "Red"),
            PollAnswer(id: "answer-2", text: "Blue")
        ],
        votes        : [String: [String]] = [:],
        endTime      : Timestamp? = nil,
        hasBeenEdited: Bool = false,
        reactions    : [Reaction] = []
    ) -> MsgLikeContent {

        MsgLikeContent(
            kind: .poll(
                question     : question,
                kind         : kind,
                maxSelections: maxSelections,
                answers      : answers,
                votes        : votes,
                endTime      : endTime,
                hasBeenEdited: hasBeenEdited
            ),
            reactions    : reactions,
            inReplyTo    : nil,
            threadRoot   : nil,
            threadSummary: nil
        )
    }
}
