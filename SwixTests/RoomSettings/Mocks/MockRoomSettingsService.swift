//
//  MockRoomSettingsService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
@testable import Swix


/// Records every metadata edit `RoomSettingsRepository` makes, and answers `snapshot(roomID:)`
/// from a stubbed value a test can update between calls to simulate the homeserver's own state
/// moving forward.
final class MockRoomSettingsService: RoomSettingsServiceProtocol {

    private(set) var renameCalls: [String] = []

    private(set) var setTopicCalls: [String] = []

    private(set) var setAvatarCallCount = 0

    private(set) var removeAvatarCallCount = 0

    private(set) var updateJoinRuleCalls: [JoinRuleSetting] = []

    private(set) var updateHistoryVisibilityCalls: [HistoryVisibilitySetting] = []

    private(set) var updateRoomVisibilityCalls: [RoomVisibilitySetting] = []

    private(set) var updateCanonicalAliasCalls: [CanonicalAliasEdit] = []

    private(set) var enableEncryptionCallCount = 0

    private(set) var setOwnMemberDisplayNameCalls: [String?] = []

    private(set) var snapshotCallCount = 0

    private(set) var shutdownCallCount = 0

    var stubbedSnapshot: RoomSettingsSnapshot

    var snapshotError: (any Error)?

    /// The one field a test sets to make the *next* write fail; every earlier and later field in
    /// the same draft is expected to still be attempted or skipped exactly as the repository's own
    /// stop-at-first-failure contract promises.
    var failingCall: RoomSettingsCall?

    init(roomID: String = "!room:example.org") {
        stubbedSnapshot = RoomSettingsSnapshot(
            roomID           : roomID,
            name             : "Room",
            topic            : nil,
            avatarURL        : nil,
            joinRule         : .invite,
            historyVisibility: .shared,
            visibility       : .private,
            canonicalAlias   : nil,
            isEncrypted      : false
        )
    }

    func rename(
        _ name: String,
        roomID: String
    ) async throws {

        renameCalls.append(name)

        try Self.failIfNeeded(.rename, matches: failingCall)
    }

    func setTopic(
        _ topic: String,
        roomID : String
    ) async throws {

        setTopicCalls.append(topic)

        try Self.failIfNeeded(.setTopic, matches: failingCall)
    }

    func setAvatar(
        data    : Data,
        mimeType: String,
        roomID  : String
    ) async throws {

        setAvatarCallCount += 1

        try Self.failIfNeeded(.setAvatar, matches: failingCall)
    }

    func removeAvatar(roomID: String) async throws {
        removeAvatarCallCount += 1

        try Self.failIfNeeded(.removeAvatar, matches: failingCall)
    }

    func updateJoinRule(
        _ joinRule: JoinRuleSetting,
        roomID    : String
    ) async throws {

        updateJoinRuleCalls.append(joinRule)

        try Self.failIfNeeded(.updateJoinRule, matches: failingCall)
    }

    func updateHistoryVisibility(
        _ visibility: HistoryVisibilitySetting,
        roomID      : String
    ) async throws {

        updateHistoryVisibilityCalls.append(visibility)

        try Self.failIfNeeded(.updateHistoryVisibility, matches: failingCall)
    }

    func updateRoomVisibility(
        _ visibility: RoomVisibilitySetting,
        roomID      : String
    ) async throws {

        updateRoomVisibilityCalls.append(visibility)

        try Self.failIfNeeded(.updateRoomVisibility, matches: failingCall)
    }

    func updateCanonicalAlias(
        _ edit: CanonicalAliasEdit,
        roomID: String
    ) async throws {

        updateCanonicalAliasCalls.append(edit)

        try Self.failIfNeeded(.updateCanonicalAlias, matches: failingCall)
    }

    func enableEncryption(roomID: String) async throws {
        enableEncryptionCallCount += 1

        try Self.failIfNeeded(.enableEncryption, matches: failingCall)
    }

    func setOwnMemberDisplayName(
        _ displayName: String?,
        roomID       : String
    ) async throws {

        setOwnMemberDisplayNameCalls.append(displayName)

        try Self.failIfNeeded(.setOwnMemberDisplayName, matches: failingCall)
    }

    func snapshot(roomID: String) async throws -> RoomSettingsSnapshot {
        snapshotCallCount += 1

        if let snapshotError {
            throw snapshotError
        }

        return stubbedSnapshot
    }

    func observeSnapshot(roomID: String) throws -> AsyncStream<RoomSettingsSnapshot> {
        AsyncStream { _ in }
    }

    func shutdown() {
        shutdownCallCount += 1
    }

    private static func failIfNeeded(
        _ call             : RoomSettingsCall,
        matches failingCall: RoomSettingsCall?
    ) throws {

        guard call == failingCall else {
            return
        }

        throw RoomSettingsFailure.updateFailed(Fixtures.sdkErrorInfo())
    }
}
