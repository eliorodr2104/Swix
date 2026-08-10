//
//  NotificationSettingsViewModel.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation


/// What a notification settings screen needs: two default modes, four toggles, and the mode of
/// whichever room is being looked at.
///
/// Matrix keeps a separate default for encrypted and unencrypted rooms, but a user does not think
/// in those terms, so the two rows offered here write both variants at once and read the encrypted
/// one back. A screen that really wants the four dimensions can still reach `defaultModes`.
@Observable
final class NotificationSettingsViewModel {

    /// The failure to present, if any. Views clear it by setting it back to nil.
    var failure: UserFacingFailure?

    @ObservationIgnored
    private let repository: NotificationSettingsRepository

    init(repository: NotificationSettingsRepository) {
        self.repository = repository
    }

    /// Whether a request is in flight, so controls can be disabled while it lands.
    var isLoading: Bool {
        repository.isLoading
    }

    /// The default mode for rooms with more than two people.
    var groupChatMode: NotificationMode {
        repository.defaultModes[.encryptedGroup] ?? .allMessages
    }

    /// The default mode for direct chats.
    var directChatMode: NotificationMode {
        repository.defaultModes[.encryptedDirect] ?? .allMessages
    }

    /// Whether being mentioned by name notifies.
    var isUserMentionEnabled: Bool {
        repository.isUserMentionEnabled
    }

    /// Whether an @room mention notifies.
    var isRoomMentionEnabled: Bool {
        repository.isRoomMentionEnabled
    }

    /// Whether incoming calls notify.
    var isCallEnabled: Bool {
        repository.isCallEnabled
    }

    /// Whether invitations notify.
    var isInviteEnabled: Bool {
        repository.isInviteEnabled
    }

    /// Loads the account wide settings. Call it when the screen appears.
    func load() async {
        await repository.load()

        updateFailure()
    }

    /// Changes the default for group rooms, encrypted and unencrypted alike.
    func setGroupChatMode(_ mode: NotificationMode) async {
        await repository.setDefaultMode(mode, for: .encryptedGroup)
        await repository.setDefaultMode(mode, for: .unencryptedGroup)

        updateFailure()
    }

    /// Changes the default for direct chats, encrypted and unencrypted alike.
    func setDirectChatMode(_ mode: NotificationMode) async {
        await repository.setDefaultMode(mode, for: .encryptedDirect)
        await repository.setDefaultMode(mode, for: .unencryptedDirect)

        updateFailure()
    }

    /// Turns notifications for personal mentions on or off.
    func setUserMentionEnabled(_ enabled: Bool) async {
        await repository.setUserMentionEnabled(enabled)

        updateFailure()
    }

    /// Turns notifications for @room mentions on or off.
    func setRoomMentionEnabled(_ enabled: Bool) async {
        await repository.setRoomMentionEnabled(enabled)

        updateFailure()
    }

    /// Turns call notifications on or off.
    func setCallEnabled(_ enabled: Bool) async {
        await repository.setCallEnabled(enabled)

        updateFailure()
    }

    /// Turns invitation notifications on or off.
    func setInviteEnabled(_ enabled: Bool) async {
        await repository.setInviteEnabled(enabled)

        updateFailure()
    }

    /// The setting a room is under, once it has been loaded.
    func setting(for roomID: String) -> RoomNotificationSetting? {
        repository.roomSettings[roomID]
    }

    /// Resolves one room's setting, defaults included.
    func loadRoom(
        roomID     : String,
        isEncrypted: Bool,
        isOneToOne : Bool
    ) async {
        await repository.load(roomID: roomID, isEncrypted: isEncrypted, isOneToOne: isOneToOne)

        updateFailure()
    }

    /// Loads whatever rules the account set on the rooms currently on screen.
    func loadRooms(roomIDs: [String]) async {
        await repository.load(roomIDs: roomIDs)

        updateFailure()
    }

    /// Overrides the mode for one room.
    func setMode(
        _ mode: NotificationMode,
        roomID: String
    ) async {
        await repository.setMode(roomID: roomID, mode: mode)

        updateFailure()
    }

    /// Puts a room back under the account default.
    func restoreDefault(roomID: String) async {
        await repository.restoreDefaultMode(roomID: roomID)

        updateFailure()
    }

    private func updateFailure() {
        guard let failure = repository.failure else {
            self.failure = nil

            return
        }

        self.failure = UserFacingFailure(
            title      : Self.title(for: failure),
            message    : failure.message,
            isRetryable: failure.isRetryable
        )
    }

    private static func title(for failure: NotificationsFailure) -> String {
        switch failure {
            case .noActiveClient: "No account is signed in"
            case .settingsUnavailable: "Could not read your notification settings"
            case .updateFailed: "Could not save your notification settings"
            case .notificationClientUnavailable: "Could not open a notification"
            case .pusherRegistrationFailed: "Could not register this device for push"
            case .sdk: "Something went wrong"
        }
    }
}
