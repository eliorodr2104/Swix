//
//  NotificationSettingsRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation
import os


/// The single source of truth for the account's notification settings, and the only writer of the
/// caches a settings screen reads.
///
/// Two granularities are kept on purpose. `load(roomIDs:)` fills the cache from the rooms that carry
/// a rule of their own, which is one request for the whole list; `load(roomID:isEncrypted:isOneToOne:)`
/// resolves a single room fully, because only the caller knows whether that room is encrypted and
/// whether it holds exactly two people, and the default depends on both.
@Observable
final class NotificationSettingsRepository {

    /// The account wide default for each kind of room, empty until the first load.
    private(set) var defaultModes: [NotificationDefaultScope: NotificationMode] = [:]

    /// Per room settings. A missing entry means the room has no rule of its own, so it follows the
    /// default for its kind.
    private(set) var roomSettings: [String: RoomNotificationSetting] = [:]

    /// Whether being mentioned by name notifies.
    private(set) var isUserMentionEnabled = true

    /// Whether an @room mention notifies.
    private(set) var isRoomMentionEnabled = true

    /// Whether incoming calls notify.
    private(set) var isCallEnabled = true

    /// Whether invitations notify.
    private(set) var isInviteEnabled = true

    /// Whether a request is in flight, so a screen can disable its controls.
    private(set) var isLoading = false

    /// The last failure, kept until the next successful request clears it.
    private(set) var failure: NotificationsFailure?

    @ObservationIgnored
    private let settingsService: any NotificationSettingsServiceProtocol

    @ObservationIgnored
    private let subscriptions = SubscriptionBag()

    @ObservationIgnored
    private var isObserving = false

    init(settingsService: any NotificationSettingsServiceProtocol) {
        self.settingsService = settingsService
    }

    /// Loads the four defaults and the global toggles, and starts watching for remote changes.
    func load() async {
        observeSettingsChangesIfNeeded()

        isLoading = true

        await loadGlobals()

        isLoading = false
    }

    /// Loads the rules the account set on specific rooms, ignoring the rooms that follow a default.
    func load(roomIDs: [String]) async {
        observeSettingsChangesIfNeeded()

        isLoading = true

        do {
            let ruled = Set(try await settingsService.roomsWithUserDefinedRules())

            for roomID in roomIDs where ruled.contains(roomID) {
                guard let mode = try await settingsService.userDefinedMode(roomID: roomID) else {
                    continue
                }

                roomSettings[roomID] = RoomNotificationSetting(mode: mode, isDefault: false)
            }

            for roomID in roomIDs where !ruled.contains(roomID) {
                roomSettings.removeValue(forKey: roomID)
            }

            failure = nil
        } catch {
            record(error)
        }

        isLoading = false
    }

    /// Resolves one room completely, including the default it would inherit.
    func load(
        roomID     : String,
        isEncrypted: Bool,
        isOneToOne : Bool
    ) async {
        observeSettingsChangesIfNeeded()

        isLoading = true

        do {
            roomSettings[roomID] = try await settingsService.setting(
                roomID     : roomID,
                isEncrypted: isEncrypted,
                isOneToOne : isOneToOne
            )

            failure = nil
        } catch {
            record(error)
        }

        isLoading = false
    }

    /// Overrides the mode for one room.
    func setMode(
        roomID: String,
        mode  : NotificationMode
    ) async {
        await perform {
            try await self.settingsService.setMode(roomID: roomID, mode: mode)

            self.roomSettings[roomID] = RoomNotificationSetting(mode: mode, isDefault: false)
        }
    }

    /// Drops the room's own rule so it follows the account default again.
    func restoreDefaultMode(roomID: String) async {
        await perform {
            try await self.settingsService.restoreDefaultMode(roomID: roomID)

            self.roomSettings.removeValue(forKey: roomID)
        }
    }

    /// Brings a muted room back to the default for its kind.
    func unmute(
        roomID     : String,
        isEncrypted: Bool,
        isOneToOne : Bool
    ) async {
        await perform {
            try await self.settingsService.unmute(
                roomID     : roomID,
                isEncrypted: isEncrypted,
                isOneToOne : isOneToOne
            )

            self.roomSettings[roomID] = try await self.settingsService.setting(
                roomID     : roomID,
                isEncrypted: isEncrypted,
                isOneToOne : isOneToOne
            )
        }
    }

    /// Changes the account wide default for one kind of room.
    func setDefaultMode(
        _ mode   : NotificationMode,
        for scope: NotificationDefaultScope
    ) async {

        await perform {
            try await self.settingsService.setDefaultMode(mode, for: scope)

            self.defaultModes[scope] = mode
        }
    }

    /// Turns notifications for personal mentions on or off.
    func setUserMentionEnabled(_ enabled: Bool) async {
        await perform {
            try await self.settingsService.setUserMentionEnabled(enabled)

            self.isUserMentionEnabled = enabled
        }
    }

    /// Turns notifications for @room mentions on or off.
    func setRoomMentionEnabled(_ enabled: Bool) async {
        await perform {
            try await self.settingsService.setRoomMentionEnabled(enabled)

            self.isRoomMentionEnabled = enabled
        }
    }

    /// Turns call notifications on or off.
    func setCallEnabled(_ enabled: Bool) async {
        await perform {
            try await self.settingsService.setCallEnabled(enabled)

            self.isCallEnabled = enabled
        }
    }

    /// Turns invitation notifications on or off.
    func setInviteEnabled(_ enabled: Bool) async {
        await perform {
            try await self.settingsService.setInviteForMeEnabled(enabled)

            self.isInviteEnabled = enabled
        }
    }

    /// Releases every subscription this repository and its service own. Called once, by the scope
    /// that created them, when the session ends.
    func shutdown() {
        subscriptions.cancelAll()
        settingsService.shutdown()
    }

    private func perform(_ body: () async throws -> Void) async {
        isLoading = true

        do {
            try await body()

            failure = nil
        } catch {
            record(error)
        }

        isLoading = false
    }

    private func loadGlobals() async {
        do {
            for scope in NotificationDefaultScope.allCases {
                defaultModes[scope] = try await settingsService.defaultMode(for: scope)
            }

            isUserMentionEnabled = try await settingsService.isUserMentionEnabled()
            isRoomMentionEnabled = try await settingsService.isRoomMentionEnabled()
            isCallEnabled = try await settingsService.isCallEnabled()
            isInviteEnabled = try await settingsService.isInviteForMeEnabled()

            failure = nil
        } catch {
            record(error)
        }
    }

    /// Push rules are account data, so another device editing them has to be reflected here without
    /// anyone asking. Only the globals and the already cached rooms are refetched.
    private func observeSettingsChangesIfNeeded() {
        guard !isObserving else {
            return
        }

        isObserving = true

        subscriptions.retain(Task { [weak self, settingsChanged = settingsService.settingsChanged] in
            for await _ in settingsChanged {
                guard let self else {
                    return
                }

                await loadGlobals()
                await load(roomIDs: Array(roomSettings.keys))
            }
        })
    }

    private func record(_ error: any Error) {
        let notificationsFailure = NotificationsFailure.wrapping(error)

        Log.notifications.error("Notification settings request failed: \(String(reflecting: error), privacy: .public)")

        failure = notificationsFailure
    }
}
