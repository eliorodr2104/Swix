//
//  RoomSettingsSnapshot.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// A read only picture of one room's editable settings, rebuilt from the SDK's `RoomInfo` (and,
/// for `visibility`, a dedicated fetch) whenever either one changes.
struct RoomSettingsSnapshot: Equatable {

    /// The room this snapshot describes.
    let roomID: String

    /// The room's name exactly as its `m.room.name` state event holds it, absent if it was never
    /// set. Deliberately not the computed display name the chat list falls back to for nameless
    /// DMs: editing that fallback would have nothing to write back to the server.
    let name: String?

    /// The room's current topic, absent if it was never set.
    let topic: String?

    /// The room's current avatar, still an `mxc://` URL that the media layer resolves.
    let avatarURL: URL?

    /// The room's current join rule, absent when the SDK could not resolve it or when it is a
    /// custom value this app has no case for.
    let joinRule: JoinRuleSetting?

    /// The room's current history visibility, absent when it is a custom value this app has no
    /// case for.
    let historyVisibility: HistoryVisibilitySetting?

    /// Whether the room is published in the homeserver's public directory. `RoomInfo` has no field
    /// for this, so it comes from a dedicated `getRoomVisibility()` call the service makes
    /// alongside `roomInfo()`.
    let visibility: RoomVisibilitySetting

    /// The room's current canonical alias, absent if it never had one.
    let canonicalAlias: String?

    /// Whether the room is encrypted. Once true this can never go back to false, which is why
    /// `RoomSettingsServiceProtocol.enableEncryption(roomID:)` documents itself as irreversible.
    let isEncrypted: Bool
}
