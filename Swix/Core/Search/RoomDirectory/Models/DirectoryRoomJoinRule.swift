//
//  DirectoryRoomJoinRule.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// How a public directory room lets new members in.
enum DirectoryRoomJoinRule: Equatable {

    /// Anyone who finds the room can join it.
    case open

    /// Anyone can ask, a moderator has to accept.
    case knock

    /// Members of some other room can join directly.
    case restricted

    /// Members of some other room can join directly, everyone else has to knock.
    case knockRestricted

    /// Only an explicit invite gets a user in.
    case inviteOnly

    /// Whether tapping the room should join it right away.
    var allowsDirectJoin: Bool {
        switch self {
            case .open, .restricted: true
            case .knock, .knockRestricted, .inviteOnly: false
        }
    }

    /// Whether tapping the room should send a knock request instead.
    var requiresKnock: Bool {
        switch self {
            case .knock, .knockRestricted: true
            case .open, .restricted, .inviteOnly: false
        }
    }
}
