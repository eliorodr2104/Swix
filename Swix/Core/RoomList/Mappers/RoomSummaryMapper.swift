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
    static func makeSummary(from room: Room) async -> RoomSummary {
        let latestEvent = await room.latestEvent()

        guard let info = try? await room.roomInfo() else {
            return await makeFallbackSummary(from: room, latestEvent: latestEvent)
        }

        return makeSummary(room: room, info: info, latestEvent: latestEvent)
    }

    /// The full mapping, for callers that already hold a fresh `RoomInfo`.
    static func makeSummary(
        room       : Room,
        info       : RoomInfo,
        latestEvent: LatestEventValue
    ) -> RoomSummary {
        RoomSummary(
            id                 : info.id,
            name               : info.displayName ?? info.canonicalAlias ?? info.id,
            avatarURL          : makeURL(from: info.avatarUrl),
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
        RoomSummary(
            id                 : room.id(),
            name               : room.displayName() ?? room.canonicalAlias() ?? room.id(),
            avatarURL          : makeURL(from: room.avatarUrl()),
            preview            : LatestEventMapper.makePreview(from: latestEvent),
            lastActivity       : LatestEventMapper.makeLastActivity(from: latestEvent),
            unreadMessages     : 0,
            unreadNotifications: 0,
            unreadMentions     : 0,
            isFavourite        : false,
            isLowPriority      : false,
            isDirect           : await room.isDirect(),
            isEncrypted        : room.encryptionState() == .encrypted,
            hasOngoingCall     : room.hasActiveRoomCall(),
            isMarkedUnread     : false
        )
    }

    /// The SDK hands back avatar addresses as plain strings, empty just as often as absent.
    private static func makeURL(from string: String?) -> URL? {
        guard let string, !string.isEmpty else {
            return nil
        }

        return URL(string: string)
    }
}
