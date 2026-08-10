//
//  RoomSettingsService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Foundation


/// The default `RoomSettingsServiceProtocol`, driving the SDK `Room` directly through the same
/// `RoomProviding` lookup the chat list's own room actions use.
final class RoomSettingsService: RoomSettingsServiceProtocol {

    private let roomProvider: any RoomProviding

    private let subscriptions = SubscriptionBag()

    // `RoomInfo` updates never carry directory visibility, only join rules do, so the value most
    // recently read by `snapshot(roomID:)` (or written by `updateRoomVisibility`) is reused by
    // `observeSnapshot(roomID:)` between those two explicit refresh points.
    private var cachedVisibility: [String: RoomVisibilitySetting] = [:]

    init(roomProvider: any RoomProviding) {
        self.roomProvider = roomProvider
    }

    func rename(
        _ name: String,
        roomID: String
    ) async throws {

        let room = try room(roomID)

        try await perform {
            try await room.setName(name: name)
        }
    }

    func setTopic(
        _ topic: String,
        roomID : String
    ) async throws {

        let room = try room(roomID)

        try await perform {
            try await room.setTopic(topic: topic)
        }
    }

    func setAvatar(
        data    : Data,
        mimeType: String,
        roomID  : String
    ) async throws {

        let room = try room(roomID)

        try await perform {
            try await room.uploadAvatar(mimeType: mimeType, data: data, mediaInfo: nil)
        }
    }

    func removeAvatar(roomID: String) async throws {
        let room = try room(roomID)

        try await perform {
            try await room.removeAvatar()
        }
    }

    func updateJoinRule(
        _ joinRule: JoinRuleSetting,
        roomID    : String
    ) async throws {

        let room = try room(roomID)
        let sdkJoinRule = RoomSettingsMapper.makeSDKJoinRule(from: joinRule)

        try await perform {
            try await room.updateJoinRules(newRule: sdkJoinRule)
        }
    }

    func updateHistoryVisibility(
        _ visibility: HistoryVisibilitySetting,
        roomID      : String
    ) async throws {

        let room = try room(roomID)
        let sdkVisibility = RoomSettingsMapper.makeSDKHistoryVisibility(from: visibility)

        try await perform {
            try await room.updateHistoryVisibility(visibility: sdkVisibility)
        }
    }

    func updateRoomVisibility(
        _ visibility: RoomVisibilitySetting,
        roomID      : String
    ) async throws {

        let room = try room(roomID)
        let sdkVisibility = RoomSettingsMapper.makeSDKVisibility(from: visibility)

        try await perform {
            try await room.updateRoomVisibility(visibility: sdkVisibility)
        }

        cachedVisibility[roomID] = visibility
    }

    func updateCanonicalAlias(
        _ edit: CanonicalAliasEdit,
        roomID: String
    ) async throws {

        let room = try room(roomID)

        try await perform {
            try await room.updateCanonicalAlias(alias: edit.alias, altAliases: edit.alternates)
        }
    }

    func enableEncryption(roomID: String) async throws {
        let room = try room(roomID)

        try await perform {
            try await room.enableEncryption()
        }
    }

    func setOwnMemberDisplayName(
        _ displayName: String?,
        roomID       : String
    ) async throws {

        let room = try room(roomID)

        try await perform {
            try await room.setOwnMemberDisplayName(displayName: displayName)
        }
    }

    func snapshot(roomID: String) async throws -> RoomSettingsSnapshot {
        let room = try room(roomID)

        do {
            async let infoTask = room.roomInfo()
            async let visibilityTask = room.getRoomVisibility()

            let (info, sdkVisibility) = try await (infoTask, visibilityTask)
            let visibility = RoomSettingsMapper.makeVisibilitySetting(from: sdkVisibility)

            cachedVisibility[roomID] = visibility

            return RoomSettingsMapper.makeSnapshot(from: info, visibility: visibility)
        } catch {
            throw RoomSettingsFailure.snapshotUnavailable(SDKErrorInfo(error))
        }
    }

    func observeSnapshot(roomID: String) throws -> AsyncStream<RoomSettingsSnapshot> {
        let room = try room(roomID)

        let (stream, listener) = makeSDKStream(of: RoomInfo.self)

        subscriptions.retain(room.subscribeToRoomInfoUpdates(listener: listener))

        let (outputStream, continuation) = AsyncStream<RoomSettingsSnapshot>.makeStream(bufferingPolicy: .unbounded)

        subscriptions.retain(Task { [weak self] in
            for await info in stream {
                let visibility = self?.cachedVisibility[roomID] ?? .private

                continuation.yield(RoomSettingsMapper.makeSnapshot(from: info, visibility: visibility))
            }

            continuation.finish()
        })

        return outputStream
    }

    func shutdown() {
        subscriptions.cancelAll()
        cachedVisibility.removeAll()
    }

    private func room(_ roomID: String) throws -> Room {
        do {
            return try roomProvider.room(withId: roomID)
        } catch {
            throw RoomSettingsFailure.roomUnavailable(SDKErrorInfo(error))
        }
    }

    private func perform(_ action: () async throws -> Void) async throws {
        do {
            try await action()
        } catch {
            throw RoomSettingsFailure.updateFailed(SDKErrorInfo(error))
        }
    }
}
