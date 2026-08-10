//
//  FoundUser.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// One user the homeserver's user directory returned.
struct FoundUser: Equatable, Identifiable {

    /// Matrix ID, unique across the federation and stable as a list identity.
    let userID: String

    /// Display name the directory published, absent for users who never set one.
    let displayName: String?

    /// MXC URI of the avatar, to be resolved by the media layer.
    let avatarURL: String?

    /// Matrix IDs are unique, which makes them a stable list identity.
    var id: String {
        userID
    }

    /// What a row should print, falling back to the raw Matrix ID.
    var name: String {
        displayName ?? userID
    }
}
