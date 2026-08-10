//
//  NotificationSettingsService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// The default `NotificationSettingsServiceProtocol`, built on `Client.getNotificationSettings()`.
final class NotificationSettingsService: NotificationSettingsServiceProtocol {

    let settingsChanged: AsyncStream<Void>

    private let clientService: any ClientServiceProtocol

    private let changeContinuation: AsyncStream<Void>.Continuation

    private let subscriptions = SubscriptionBag()

    private var settings: NotificationSettings?

    // The SDK takes the delegate without handing back a TaskHandle, so this reference is the only
    // thing keeping the bridge alive for as long as the session lasts.
    private var changeListener: SDKListener<SDKNotificationSettingsEvent>?

    init(clientService: any ClientServiceProtocol) {
        self.clientService = clientService

        (settingsChanged, changeContinuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .unbounded)
    }

    func defaultMode(for scope: NotificationDefaultScope) async throws -> NotificationMode {
        let settings = try await activeSettings()

        let mode = await settings.getDefaultRoomNotificationMode(
            isEncrypted: scope.isEncrypted,
            isOneToOne : scope.isOneToOne
        )

        return RoomNotificationSettingMapper.makeMode(from: mode)
    }

    func setDefaultMode(
        _ mode   : NotificationMode,
        for scope: NotificationDefaultScope
    ) async throws {
        let settings = try await activeSettings()

        do {
            try await settings.setDefaultRoomNotificationMode(
                isEncrypted: scope.isEncrypted,
                isOneToOne : scope.isOneToOne,
                mode       : RoomNotificationSettingMapper.makeSDKMode(from: mode)
            )
        } catch {
            throw NotificationsFailure.updateFailed(SDKErrorInfo(error))
        }
    }

    func setting(
        roomID     : String,
        isEncrypted: Bool,
        isOneToOne : Bool
    ) async throws -> RoomNotificationSetting {
        let settings = try await activeSettings()

        do {
            let resolved = try await settings.getRoomNotificationSettings(
                roomId     : roomID,
                isEncrypted: isEncrypted,
                isOneToOne : isOneToOne
            )

            return RoomNotificationSettingMapper.makeSetting(from: resolved)
        } catch {
            throw NotificationsFailure.settingsUnavailable(SDKErrorInfo(error))
        }
    }

    func userDefinedMode(roomID: String) async throws -> NotificationMode? {
        let settings = try await activeSettings()

        do {
            guard let mode = try await settings.getUserDefinedRoomNotificationMode(roomId: roomID) else {
                return nil
            }

            return RoomNotificationSettingMapper.makeMode(from: mode)
        } catch {
            throw NotificationsFailure.settingsUnavailable(SDKErrorInfo(error))
        }
    }

    func setMode(
        roomID: String,
        mode  : NotificationMode
    ) async throws {
        let settings = try await activeSettings()

        do {
            try await settings.setRoomNotificationMode(
                roomId: roomID,
                mode  : RoomNotificationSettingMapper.makeSDKMode(from: mode)
            )
        } catch {
            throw NotificationsFailure.updateFailed(SDKErrorInfo(error))
        }
    }

    func restoreDefaultMode(roomID: String) async throws {
        let settings = try await activeSettings()

        do {
            try await settings.restoreDefaultRoomNotificationMode(roomId: roomID)
        } catch {
            throw NotificationsFailure.updateFailed(SDKErrorInfo(error))
        }
    }

    func unmute(
        roomID     : String,
        isEncrypted: Bool,
        isOneToOne : Bool
    ) async throws {
        let settings = try await activeSettings()

        do {
            try await settings.unmuteRoom(roomId: roomID, isEncrypted: isEncrypted, isOneToOne: isOneToOne)
        } catch {
            throw NotificationsFailure.updateFailed(SDKErrorInfo(error))
        }
    }

    func roomsWithUserDefinedRules() async throws -> [String] {
        let settings = try await activeSettings()

        return await settings.getRoomsWithUserDefinedRules(enabled: nil)
    }

    func isUserMentionEnabled() async throws -> Bool {
        try await read { try await $0.isUserMentionEnabled() }
    }

    func setUserMentionEnabled(_ enabled: Bool) async throws {
        try await write { try await $0.setUserMentionEnabled(enabled: enabled) }
    }

    func isRoomMentionEnabled() async throws -> Bool {
        try await read { try await $0.isRoomMentionEnabled() }
    }

    func setRoomMentionEnabled(_ enabled: Bool) async throws {
        try await write { try await $0.setRoomMentionEnabled(enabled: enabled) }
    }

    func isCallEnabled() async throws -> Bool {
        try await read { try await $0.isCallEnabled() }
    }

    func setCallEnabled(_ enabled: Bool) async throws {
        try await write { try await $0.setCallEnabled(enabled: enabled) }
    }

    func isInviteForMeEnabled() async throws -> Bool {
        try await read { try await $0.isInviteForMeEnabled() }
    }

    func setInviteForMeEnabled(_ enabled: Bool) async throws {
        try await write { try await $0.setInviteForMeEnabled(enabled: enabled) }
    }

    func shutdown() {
        settings?.setDelegate(delegate: nil)

        subscriptions.cancelAll()

        changeListener = nil
        settings = nil
    }

    private func read<Value>(_ body: (NotificationSettings) async throws -> Value) async throws -> Value {
        let settings = try await activeSettings()

        do {
            return try await body(settings)
        } catch {
            throw NotificationsFailure.settingsUnavailable(SDKErrorInfo(error))
        }
    }

    private func write(_ body: (NotificationSettings) async throws -> Void) async throws {
        let settings = try await activeSettings()

        do {
            try await body(settings)
        } catch {
            throw NotificationsFailure.updateFailed(SDKErrorInfo(error))
        }
    }

    /// Fetches the settings object once and keeps it: it is the owner of the delegate, so building
    /// a second one would silently detach the change stream from the rules being edited.
    private func activeSettings() async throws -> NotificationSettings {
        if let settings {
            return settings
        }

        guard let client = clientService.sdkClient else {
            throw NotificationsFailure.noActiveClient
        }

        let settings = await client.getNotificationSettings()

        self.settings = settings
        observe(settings)

        return settings
    }

    private func observe(_ settings: NotificationSettings) {
        let (stream, listener) = makeSDKStream(of: SDKNotificationSettingsEvent.self)

        changeListener = listener
        settings.setDelegate(delegate: listener)

        subscriptions.retain(Task { [changeContinuation] in
            for await _ in stream {
                changeContinuation.yield(())
            }
        })
    }
}
