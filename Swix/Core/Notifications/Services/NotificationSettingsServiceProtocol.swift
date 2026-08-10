//
//  NotificationSettingsServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Reads and writes the account's push rules: the four defaults, the per room overrides and the
/// handful of global toggles Matrix exposes as named rules.
protocol NotificationSettingsServiceProtocol {

    /// Fires whenever the homeserver's push rules change, from this device or from another one.
    /// The stream starts delivering once the settings have been touched for the first time.
    var settingsChanged: AsyncStream<Void> { get }

    /// The account wide default for one kind of room.
    func defaultMode(for scope: NotificationDefaultScope) async throws -> NotificationMode

    /// Changes the account wide default for one kind of room.
    func setDefaultMode(
        _ mode   : NotificationMode,
        for scope: NotificationDefaultScope
    ) async throws

    /// The mode actually in force for a room, together with whether it is inherited.
    func setting(
        roomID     : String,
        isEncrypted: Bool,
        isOneToOne : Bool
    ) async throws -> RoomNotificationSetting

    /// The mode a rule sets on this room specifically, nil when the room follows the default.
    /// Cheaper than `setting(roomID:isEncrypted:isOneToOne:)` because it needs no room traits.
    func userDefinedMode(roomID: String) async throws -> NotificationMode?

    /// Overrides the mode for a single room.
    func setMode(
        roomID: String,
        mode  : NotificationMode
    ) async throws

    /// Drops the room's own rule so it follows the account default again.
    func restoreDefaultMode(roomID: String) async throws

    /// Brings a muted room back to whatever its default would be.
    func unmute(
        roomID     : String,
        isEncrypted: Bool,
        isOneToOne : Bool
    ) async throws

    /// Every room the account has set a rule on, which is the working set worth caching.
    func roomsWithUserDefinedRules() async throws -> [String]

    /// Whether being mentioned by name notifies.
    func isUserMentionEnabled() async throws -> Bool

    /// Turns notifications for personal mentions on or off.
    func setUserMentionEnabled(_ enabled: Bool) async throws

    /// Whether an @room mention notifies.
    func isRoomMentionEnabled() async throws -> Bool

    /// Turns notifications for @room mentions on or off.
    func setRoomMentionEnabled(_ enabled: Bool) async throws

    /// Whether incoming calls notify.
    func isCallEnabled() async throws -> Bool

    /// Turns call notifications on or off.
    func setCallEnabled(_ enabled: Bool) async throws

    /// Whether invitations notify.
    func isInviteForMeEnabled() async throws -> Bool

    /// Turns invitation notifications on or off.
    func setInviteForMeEnabled(_ enabled: Bool) async throws

    /// Releases the delegate bridge. Called once, when the session ends.
    func shutdown()
}
