//
//  NotificationDefaultScope.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// The four account wide defaults the homeserver keeps, one per kind of room.
///
/// Matrix derives a room's default mode from whether it is encrypted and whether it holds exactly
/// two people, so a settings screen has to read and write all four independently.
enum NotificationDefaultScope: Hashable, CaseIterable {

    /// Encrypted rooms with more than two members.
    case encryptedGroup

    /// Encrypted direct chats.
    case encryptedDirect

    /// Unencrypted rooms with more than two members.
    case unencryptedGroup

    /// Unencrypted direct chats.
    case unencryptedDirect

    /// Whether this scope covers encrypted rooms.
    var isEncrypted: Bool {
        switch self {
            case .encryptedGroup, .encryptedDirect: true
            case .unencryptedGroup, .unencryptedDirect: false
        }
    }

    /// Whether this scope covers direct chats between exactly two people.
    var isOneToOne: Bool {
        switch self {
            case .encryptedDirect, .unencryptedDirect: true
            case .encryptedGroup, .unencryptedGroup: false
        }
    }

    /// The scope a room with these traits falls into.
    static func scope(
        isEncrypted: Bool,
        isOneToOne : Bool
    ) -> NotificationDefaultScope {
        switch (isEncrypted, isOneToOne) {
            case (true, true): .encryptedDirect
            case (true, false): .encryptedGroup
            case (false, true): .unencryptedDirect
            case (false, false): .unencryptedGroup
        }
    }
}
