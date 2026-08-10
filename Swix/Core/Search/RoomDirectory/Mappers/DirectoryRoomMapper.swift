//
//  DirectoryRoomMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Turns the SDK's room directory stream into domain rooms and domain diffs.
enum DirectoryRoomMapper {

    /// Maps one batch of SDK updates, preserving order and indices so the batch can be applied
    /// atomically.
    static func makeDiffs(from updates: [RoomDirectorySearchEntryUpdate]) -> [CollectionDiff<DirectoryRoom>] {
        updates.map { update in
            switch update {
                case .append(let values): .append(values.map { makeRoom(from: $0) })
                case .clear: .clear
                case .pushFront(let value): .pushFront(makeRoom(from: value))
                case .pushBack(let value): .pushBack(makeRoom(from: value))
                case .popFront: .popFront
                case .popBack: .popBack
                case .insert(let index, let value): .insert(index: Int(index), element: makeRoom(from: value))
                case .set(let index, let value): .set(index: Int(index), element: makeRoom(from: value))
                case .remove(let index): .remove(index: Int(index))
                case .truncate(let length): .truncate(length: Int(length))
                case .reset(let values): .reset(values.map { makeRoom(from: $0) })
            }
        }
    }

    /// Maps a single directory entry.
    static func makeRoom(from description: RoomDescription) -> DirectoryRoom {
        DirectoryRoom(
            id             : description.roomId,
            name           : description.name,
            topic          : description.topic,
            alias          : description.alias,
            avatarURL      : description.avatarUrl,
            memberCount    : Int(description.joinedMembers),
            joinRule       : description.joinRule.map { makeJoinRule(from: $0) },
            isWorldReadable: description.isWorldReadable
        )
    }

    /// Maps the directory's join rule. The SDK's `.invite` becomes `.inviteOnly` so the domain name
    /// says what the rule denies rather than what it allows.
    static func makeJoinRule(from rule: PublicRoomJoinRule) -> DirectoryRoomJoinRule {
        switch rule {
            case .public: .open
            case .knock: .knock
            case .restricted: .restricted
            case .knockRestricted: .knockRestricted
            case .invite: .inviteOnly
        }
    }
}
