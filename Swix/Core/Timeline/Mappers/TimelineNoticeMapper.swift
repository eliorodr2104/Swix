//
//  TimelineNoticeMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Writes the one line note that stands in for every timeline event which is not a message.
///
/// Membership changes, room metadata edits, calls, redactions and events this build cannot parse
/// share a single row shape, so the whole variety of the SDK's content model is spent here, once,
/// and the timeline downstream only ever sees a finished sentence.
enum TimelineNoticeMapper {

    /// Builds the notice for an event the entry mapper decided is not a message.
    static func makeNotice(
        from event: EventTimelineItem,
        id        : String
    ) -> TimelineNotice {

        let senderName = TimelineEntryMapper.makeSenderDisplayName(from: event.senderProfile) ?? event.sender

        return TimelineNotice(
            id       : id,
            text     : makeText(from: event.content, senderName: senderName),
            timestamp: TimelineEntryMapper.makeDate(from: event.timestamp)
        )
    }

    private static func makeText(
        from content: TimelineItemContent,
        senderName  : String
    ) -> String {

        switch content {
            case .msgLike(let msgLike):
                return makeText(from: msgLike.kind, senderName: senderName)

            case .callInvite:
                return "\(senderName) started a call"

            case .rtcNotification:
                return "\(senderName) called"

            case .roomMembership(_, let userDisplayName, let change, let reason):
                return makeText(
                    from  : change,
                    name  : userDisplayName ?? senderName,
                    reason: reason
                )

            case .profileChange(let displayName, let prevDisplayName, let avatarUrl, let prevAvatarUrl):
                return makeText(
                    displayName    : displayName,
                    prevDisplayName: prevDisplayName,
                    avatarUrl      : avatarUrl,
                    prevAvatarUrl  : prevAvatarUrl,
                    senderName     : senderName
                )

            case .state(_, let state):
                return makeText(from: state, senderName: senderName)

            case .failedToParseMessageLike(let eventType, _):
                return "\(senderName) sent a message this app cannot read (\(eventType))"

            case .failedToParseState(let eventType, _, _):
                return "An event this app cannot read changed the room (\(eventType))"
        }
    }

    /// Only two message kinds ever reach here, redactions and event types this build does not
    /// render; the rest are listed so a new SDK case cannot slip through as a wrong sentence.
    private static func makeText(
        from kind : MsgLikeKind,
        senderName: String
    ) -> String {

        switch kind {
            case .redacted: "\(senderName) deleted a message"
            case .other(let eventType): "\(senderName) sent an unsupported event (\(String(describing: eventType)))"
            case .message, .sticker, .poll, .unableToDecrypt, .liveLocation: "\(senderName) sent a message"
        }
    }

    /// The reason is only appended where it is the point of the sentence, which is bans and kicks:
    /// on everything else the homeserver rarely sets one and it reads as noise when it does.
    private static func makeText(
        from change: MembershipChange?,
        name       : String,
        reason     : String?
    ) -> String {

        guard let change else {
            return unknownMembershipText(for: name)
        }

        return switch change {
            case .joined: "\(name) joined"
            case .left: "\(name) left"
            case .banned, .kickedAndBanned: append(reason, to: "\(name) was banned")
            case .unbanned: "\(name) was unbanned"
            case .kicked: append(reason, to: "\(name) was removed")
            case .invited: "\(name) was invited"
            case .invitationAccepted: "\(name) accepted the invitation"
            case .invitationRejected: "\(name) declined the invitation"
            case .invitationRevoked: "\(name)'s invitation was withdrawn"
            case .knocked: "\(name) asked to join"
            case .knockAccepted: "\(name) was let in"
            case .knockRetracted: "\(name) withdrew their request to join"
            case .knockDenied: "\(name)'s request to join was declined"
            case .none, .error, .notImplemented: unknownMembershipText(for: name)
        }
    }

    private static func unknownMembershipText(for name: String) -> String {
        "\(name) updated their membership"
    }

    private static func makeText(
        displayName    : String?,
        prevDisplayName: String?,
        avatarUrl      : String?,
        prevAvatarUrl  : String?,
        senderName     : String
    ) -> String {

        let previousName = prevDisplayName ?? senderName

        if displayName != prevDisplayName {
            guard let displayName else {
                return "\(previousName) removed their display name"
            }

            return "\(previousName) is now known as \(displayName)"
        }

        guard avatarUrl != prevAvatarUrl else {
            return "\(senderName) updated their profile"
        }

        return avatarUrl == nil ? "\(senderName) removed their photo" : "\(senderName) changed their photo"
    }

    private static func makeText(
        from state: OtherState,
        senderName: String
    ) -> String {

        switch state {
            case .roomAvatar(let url): url == nil ? "\(senderName) removed the room photo" : "\(senderName) changed the room photo"
            case .roomName(let name): name.map { "\(senderName) changed the room name to \($0)" } ?? "\(senderName) removed the room name"
            case .roomTopic(let topic): topic.map { "\(senderName) changed the topic to \($0)" } ?? "\(senderName) removed the topic"
            case .roomCreate: "\(senderName) created this room"
            case .roomEncryption: "\(senderName) turned on encryption"
            case .roomCanonicalAlias: "\(senderName) changed the room address"
            case .roomGuestAccess: "\(senderName) changed guest access"
            case .roomHistoryVisibility: "\(senderName) changed who can read the history"
            case .roomJoinRules: "\(senderName) changed who can join"
            case .roomPinnedEvents: "\(senderName) changed the pinned messages"
            case .roomPowerLevels: "\(senderName) changed the permissions"
            case .roomServerAcl: "\(senderName) changed which servers are allowed"
            case .roomThirdPartyInvite(let displayName): displayName.map { "\(senderName) invited \($0)" } ?? "\(senderName) sent an invitation"
            case .roomTombstone: "\(senderName) replaced this room with a new version"
            case .policyRuleRoom, .policyRuleServer, .policyRuleUser: "\(senderName) changed a moderation policy"
            case .spaceChild: "\(senderName) changed the rooms in this space"
            case .spaceParent: "\(senderName) changed the parent space"
            case .custom(let eventType): "\(senderName) sent a \(eventType) event"
        }
    }

    private static func append(
        _ reason: String?,
        to text : String
    ) -> String {

        guard let reason, !reason.isEmpty else {
            return text
        }

        return "\(text): \(reason)"
    }
}
