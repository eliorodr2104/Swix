//
//  DirectoryRoom.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// One room as the public room directory describes it, before the account has anything to do with it.
struct DirectoryRoom: Equatable, Identifiable {

    /// Matrix room ID, unique across the federation and stable as a list identity.
    let id: String

    /// Name the room publishes, absent for rooms that never set one.
    let name: String?

    /// Topic the room publishes, absent for rooms that never set one.
    let topic: String?

    /// Canonical alias, absent for rooms that were never aliased.
    let alias: String?

    /// MXC URI of the room avatar, to be resolved by the media layer.
    let avatarURL: String?

    /// How many users have joined, as the directory last counted them.
    let memberCount: Int

    /// How the room lets people in, absent when the server did not say.
    let joinRule: DirectoryRoomJoinRule?

    /// Whether the room's history is readable without joining.
    let isWorldReadable: Bool

    /// What a row should print, falling back to the alias and then to the raw ID.
    var displayName: String {
        name ?? alias ?? id
    }

    /// Whether tapping the room should join it right away. A room the directory advertises without
    /// stating a join rule is assumed joinable, which is what publishing it means.
    var isJoinable: Bool {
        joinRule?.allowsDirectJoin ?? true
    }
}
