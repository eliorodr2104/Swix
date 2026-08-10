//
//  MockNotificationSettingsService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

@testable import Swix


/// Records every read and write `NotificationSettingsRepository` makes, with per-scope and
/// per-room stubs a test can seed before exercising it.
final class MockNotificationSettingsService: NotificationSettingsServiceProtocol {

    let settingsChanged: AsyncStream<Void>

    let changeContinuation: AsyncStream<Void>.Continuation

    var defaultModes: [NotificationDefaultScope: NotificationMode] = [
        .encryptedGroup: .allMessages,
        .encryptedDirect: .allMessages,
        .unencryptedGroup: .allMessages,
        .unencryptedDirect: .allMessages
    ]

    var roomSettingsByID: [String: RoomNotificationSetting] = [:]

    var userDefinedModesByID: [String: NotificationMode] = [:]

    var roomsWithRules: [String] = []

    var isUserMentionEnabledValue = true

    var isRoomMentionEnabledValue = true

    var isCallEnabledValue = true

    var isInviteForMeEnabledValue = true

    private(set) var setModeCalls: [(roomID: String, mode: NotificationMode)] = []

    private(set) var restoreDefaultCalls: [String] = []

    private(set) var unmuteCalls: [String] = []

    private(set) var setDefaultModeCalls: [(mode: NotificationMode, scope: NotificationDefaultScope)] = []

    private(set) var shutdownCallCount = 0

    var failureToThrow: (any Error)?

    init() {
        (settingsChanged, changeContinuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .unbounded)
    }

    func defaultMode(for scope: NotificationDefaultScope) async throws -> NotificationMode {
        if let failureToThrow {
            throw failureToThrow
        }

        return defaultModes[scope] ?? .allMessages
    }

    func setDefaultMode(
        _ mode   : NotificationMode,
        for scope: NotificationDefaultScope
    ) async throws {

        if let failureToThrow {
            throw failureToThrow
        }

        setDefaultModeCalls.append((mode, scope))
        defaultModes[scope] = mode
    }

    func setting(
        roomID     : String,
        isEncrypted: Bool,
        isOneToOne : Bool
    ) async throws -> RoomNotificationSetting {

        if let failureToThrow {
            throw failureToThrow
        }

        return roomSettingsByID[roomID] ?? RoomNotificationSetting(mode: .allMessages, isDefault: true)
    }

    func userDefinedMode(roomID: String) async throws -> NotificationMode? {
        if let failureToThrow {
            throw failureToThrow
        }

        return userDefinedModesByID[roomID]
    }

    func setMode(
        roomID: String,
        mode  : NotificationMode
    ) async throws {

        if let failureToThrow {
            throw failureToThrow
        }

        setModeCalls.append((roomID, mode))
        roomSettingsByID[roomID] = RoomNotificationSetting(mode: mode, isDefault: false)
    }

    func restoreDefaultMode(roomID: String) async throws {
        if let failureToThrow {
            throw failureToThrow
        }

        restoreDefaultCalls.append(roomID)
        roomSettingsByID.removeValue(forKey: roomID)
    }

    func unmute(
        roomID     : String,
        isEncrypted: Bool,
        isOneToOne : Bool
    ) async throws {

        if let failureToThrow {
            throw failureToThrow
        }

        unmuteCalls.append(roomID)
    }

    func roomsWithUserDefinedRules() async throws -> [String] {
        if let failureToThrow {
            throw failureToThrow
        }

        return roomsWithRules
    }

    func isUserMentionEnabled() async throws -> Bool {
        if let failureToThrow {
            throw failureToThrow
        }

        return isUserMentionEnabledValue
    }

    func setUserMentionEnabled(_ enabled: Bool) async throws {
        if let failureToThrow {
            throw failureToThrow
        }

        isUserMentionEnabledValue = enabled
    }

    func isRoomMentionEnabled() async throws -> Bool {
        if let failureToThrow {
            throw failureToThrow
        }

        return isRoomMentionEnabledValue
    }

    func setRoomMentionEnabled(_ enabled: Bool) async throws {
        if let failureToThrow {
            throw failureToThrow
        }

        isRoomMentionEnabledValue = enabled
    }

    func isCallEnabled() async throws -> Bool {
        if let failureToThrow {
            throw failureToThrow
        }

        return isCallEnabledValue
    }

    func setCallEnabled(_ enabled: Bool) async throws {
        if let failureToThrow {
            throw failureToThrow
        }

        isCallEnabledValue = enabled
    }

    func isInviteForMeEnabled() async throws -> Bool {
        if let failureToThrow {
            throw failureToThrow
        }

        return isInviteForMeEnabledValue
    }

    func setInviteForMeEnabled(_ enabled: Bool) async throws {
        if let failureToThrow {
            throw failureToThrow
        }

        isInviteForMeEnabledValue = enabled
    }

    func shutdown() {
        shutdownCallCount += 1
    }
}
