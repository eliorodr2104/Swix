//
//  RoomSummaryMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import MatrixRustSDK


/// Flattens an SDK room into the immutable `RoomSummary` the chat list renders.
enum RoomSummaryMapper {

    /// Reads everything a chat row needs out of one room.
    ///
    /// `roomInfo()` is the only source of the unread counters and the favourite flags, so it is
    /// always attempted first; when it fails the cheap synchronous accessors still produce a row
    /// worth showing rather than dropping the room out of the list entirely.
    static func makeSummary(
        from room: Room,
        ownUserID: String
    ) async -> RoomSummary {
        let latestEvent = await room.latestEvent()

        guard let info = try? await room.roomInfo() else {
            return await makeFallbackSummary(from: room, latestEvent: latestEvent)
        }

        let avatarUrl = await resolveAvatarUrl(
            of       : room,
            info     : info,
            ownUserID: ownUserID
        )

        return makeSummary(
            room             : room,
            info             : info,
            resolvedAvatarUrl: avatarUrl,
            latestEvent      : latestEvent
        )
    }

    /// The full mapping, for callers that already resolved which avatar the row should wear.
    static func makeSummary(
        room             : Room,
        info             : RoomInfo,
        resolvedAvatarUrl: String?,
        latestEvent      : LatestEventValue
    ) -> RoomSummary {
        RoomSummary(
            id                 : info.id,
            name               : info.displayName ?? info.canonicalAlias ?? info.id,
            avatarURL          : makeURL(from: resolvedAvatarUrl),
            preview            : LatestEventMapper.makePreview(from: latestEvent),
            lastActivity       : LatestEventMapper.makeLastActivity(from: latestEvent),
            unreadMessages     : Int(info.numUnreadMessages),
            unreadNotifications: Int(info.numUnreadNotifications),
            unreadMentions     : Int(info.numUnreadMentions),
            isFavourite        : info.isFavourite,
            isLowPriority      : info.isLowPriority,
            isDirect           : info.isDirect,
            isEncrypted        : info.encryptionState == .encrypted,
            hasOngoingCall     : info.hasRoomCall,
            isMarkedUnread     : info.isMarkedUnread
        )
    }

    /// Falls back to the room's synchronous accessors when `roomInfo()` could not be fetched, so a
    /// transient failure costs the row's freshness rather than the row itself.
    private static func makeFallbackSummary(
        from room  : Room,
        latestEvent: LatestEventValue
    ) async -> RoomSummary {
        let isDirect = await room.isDirect()
        let heroes   = await room.heroes()

        return RoomSummary(
            id                 : room.id(),
            name               : room.displayName() ?? room.canonicalAlias() ?? room.id(),
            avatarURL          : makeURL(from: room.avatarUrl() ?? heroAvatar(isDirect: isDirect, heroes: heroes)),
            preview            : LatestEventMapper.makePreview(from: latestEvent),
            lastActivity       : LatestEventMapper.makeLastActivity(from: latestEvent),
            unreadMessages     : 0,
            unreadNotifications: 0,
            unreadMentions     : 0,
            isFavourite        : false,
            isLowPriority      : false,
            isDirect           : isDirect,
            isEncrypted        : room.encryptionState() == .encrypted,
            hasOngoingCall     : room.hasActiveRoomCall(),
            isMarkedUnread     : false
        )
    }

    /// A direct room rarely carries an avatar of its own: the face the user expects there is the
    /// other member's, which the SDK hands over as the room's first hero.
    private static func heroAvatar(
        isDirect: Bool,
        heroes  : [RoomHero]
    ) -> String? {

        guard isDirect else {
            return nil
        }

        return heroes.first?.avatarUrl
    }

    /// The avatar of a direct room is a chase: the room's own, then the summary's heroes, then the
    /// heroes computed on demand, and finally the other member read straight from the member list,
    /// because sliding sync happily delivers a DM with all three cheaper sources empty.
    private static func resolveAvatarUrl(
        of room  : Room,
        info     : RoomInfo,
        ownUserID: String
    ) async -> String? {

        if let avatar = info.avatarUrl {
            return avatar
        }

        guard info.isDm else {
            return nil
        }

        if let avatar = info.heroes.first?.avatarUrl {
            return avatar
        }

        if let avatar = await room.heroes().first?.avatarUrl {
            return avatar
        }

        return await partnerAvatarUrl(
            of       : room,
            ownUserID: ownUserID
        )
    }

    /// Walks the member list of a direct room and hands back the other person's avatar.
    private static func partnerAvatarUrl(
        of room  : Room,
        ownUserID: String
    ) async -> String? {

        guard let members = try? await room.members() else {
            return nil
        }

        while let chunk = members.nextChunk(chunkSize: 20) {
            if let partner = chunk.first(where: { $0.userId != ownUserID && !$0.isServiceMember }) {
                return partner.avatarUrl
            }
        }

        return nil
    }

    /// The SDK hands back avatar addresses as plain strings, empty just as often as absent.
    private static func makeURL(from string: String?) -> URL? {
        guard let string, !string.isEmpty else {
            return nil
        }

        return URL(string: string)
    }
}
