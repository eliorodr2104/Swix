//
//  RoomSettingsServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Every metadata edit a room settings screen can make, plus the read side that feeds
/// `RoomSettingsRepository`'s snapshot.
protocol RoomSettingsServiceProtocol {

    /// Renames the room, i.e. sets its `m.room.name` state event.
    func rename(
        _ name: String,
        roomID: String
    ) async throws

    /// Sets the room's topic.
    func setTopic(
        _ topic: String,
        roomID : String
    ) async throws

    /// Uploads and sets a new room avatar from already loaded image data.
    func setAvatar(
        data    : Data,
        mimeType: String,
        roomID  : String
    ) async throws

    /// Removes the room's avatar entirely, rather than replacing it.
    func removeAvatar(roomID: String) async throws

    /// Changes who is allowed to join the room without an invite.
    func updateJoinRule(
        _ joinRule: JoinRuleSetting,
        roomID    : String
    ) async throws

    /// Changes how far back new members can read the room's history.
    func updateHistoryVisibility(
        _ visibility: HistoryVisibilitySetting,
        roomID      : String
    ) async throws

    /// Publishes or unpublishes the room from the homeserver's public room directory.
    func updateRoomVisibility(
        _ visibility: RoomVisibilitySetting,
        roomID      : String
    ) async throws

    /// Replaces the room's canonical alias and alternates together.
    func updateCanonicalAlias(
        _ edit: CanonicalAliasEdit,
        roomID: String
    ) async throws

    /// Turns on end to end encryption for the room. Irreversible: the SDK exposes no call to turn
    /// it back off, matching the Matrix spec's own rule that `m.room.encryption` cannot be unset
    /// once it exists.
    func enableEncryption(roomID: String) async throws

    /// Changes the account's own display name inside this room only, or clears it back to the
    /// account wide profile name when `displayName` is `nil`.
    func setOwnMemberDisplayName(
        _ displayName: String?,
        roomID       : String
    ) async throws

    /// The room's current settings, mapped from `RoomInfo` and a dedicated directory visibility
    /// fetch.
    func snapshot(roomID: String) async throws -> RoomSettingsSnapshot

    /// Every later snapshot, following the room's own `RoomInfo` updates. There is no initial
    /// replay here; `snapshot(roomID:)` is what a caller uses to get the first value.
    func observeSnapshot(roomID: String) throws -> AsyncStream<RoomSettingsSnapshot>

    /// Releases every subscription this service owns. Called once, when the session ends.
    func shutdown()
}
