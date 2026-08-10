//
//  RoomSettingsMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Foundation


/// Builds a `RoomSettingsSnapshot` out of the SDK's `RoomInfo`, and translates the SDK-free
/// setting enums to and from their `MatrixRustSDK` counterparts.
enum RoomSettingsMapper {

    /// The full mapping. `visibility` is a separate parameter because `RoomInfo` has no field for
    /// it; the caller fetches it from `Room.getRoomVisibility()` alongside `roomInfo()`.
    static func makeSnapshot(
        from info : RoomInfo,
        visibility: RoomVisibilitySetting
    ) -> RoomSettingsSnapshot {

        RoomSettingsSnapshot(
            roomID           : info.id,
            name             : info.rawName,
            topic            : info.topic,
            avatarURL        : makeURL(from: info.avatarUrl),
            joinRule         : makeJoinRuleSetting(from: info.joinRule),
            historyVisibility: makeHistoryVisibilitySetting(from: info.historyVisibility),
            visibility       : visibility,
            canonicalAlias   : info.canonicalAlias,
            isEncrypted      : info.encryptionState == .encrypted
        )
    }

    /// `nil` both when the SDK could not resolve a join rule and when it resolved one this app has
    /// no case for (`.private`, which the spec reserves and no homeserver actually sends, or a
    /// server specific `.custom` string).
    static func makeJoinRuleSetting(from joinRule: JoinRule?) -> JoinRuleSetting? {
        guard let joinRule else {
            return nil
        }

        switch joinRule {
            case .public: return .public
            case .invite: return .invite
            case .knock: return .knock
            case .restricted(let rules): return .restricted(roomIDs: roomIDs(from: rules))
            case .knockRestricted(let rules): return .knockRestricted(roomIDs: roomIDs(from: rules))
            case .private, .custom: return nil
        }
    }

    static func makeSDKJoinRule(from setting: JoinRuleSetting) -> JoinRule {
        switch setting {
            case .public: .public
            case .invite: .invite
            case .knock: .knock
            case .restricted(let roomIDs): .restricted(rules: allowRules(from: roomIDs))
            case .knockRestricted(let roomIDs): .knockRestricted(rules: allowRules(from: roomIDs))
        }
    }

    /// `nil` when the room used a server specific `.custom` history visibility this app has no
    /// case for, rather than silently reporting one of the known values instead.
    static func makeHistoryVisibilitySetting(from visibility: RoomHistoryVisibility) -> HistoryVisibilitySetting? {
        switch visibility {
            case .invited: .invited
            case .joined: .joined
            case .shared: .shared
            case .worldReadable: .worldReadable
            case .custom: nil
        }
    }

    static func makeSDKHistoryVisibility(from setting: HistoryVisibilitySetting) -> RoomHistoryVisibility {
        switch setting {
            case .invited: .invited
            case .joined: .joined
            case .shared: .shared
            case .worldReadable: .worldReadable
        }
    }

    static func makeSDKVisibility(from setting: RoomVisibilitySetting) -> RoomVisibility {
        switch setting {
            case .public: .public
            case .private: .private
        }
    }

    /// A server specific `.custom` visibility is treated as `.private`, the safer of the two
    /// assumptions when the server did not use one of the two documented values.
    static func makeVisibilitySetting(from visibility: RoomVisibility) -> RoomVisibilitySetting {
        switch visibility {
            case .public: .public
            case .private, .custom: .private
        }
    }

    private static func roomIDs(from rules: [AllowRule]) -> [String] {
        rules.compactMap { rule in
            guard case .roomMembership(let roomID) = rule else {
                return nil
            }

            return roomID
        }
    }

    private static func allowRules(from roomIDs: [String]) -> [AllowRule] {
        roomIDs.map { .roomMembership(roomId: $0) }
    }

    private static func makeURL(from string: String?) -> URL? {
        guard let string, !string.isEmpty else {
            return nil
        }

        return URL(string: string)
    }
}
