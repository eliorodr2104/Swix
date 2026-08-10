//
//  RoomSettingsRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation
import Foundation
import os


/// The single source of truth for one room's settings screen, and the only writer of `snapshot`.
///
/// Scoped to a single room rather than the whole account: a settings screen only ever edits the
/// room it is showing, so there is nothing to gain from a repository that tracked every room's
/// settings at once the way `RoomListRepository` tracks every room's summary.
@Observable
final class RoomSettingsRepository {

    /// The room's settings as of the last load or push update, `nil` until `start()` completes.
    private(set) var snapshot: RoomSettingsSnapshot?

    /// Whether a change is currently being sent, so a screen can disable its controls.
    private(set) var isApplying = false

    /// The last failure, kept until the next successful request clears it.
    private(set) var failure: RoomSettingsFailure?

    @ObservationIgnored
    private let roomID: String

    @ObservationIgnored
    private let settingsService: any RoomSettingsServiceProtocol

    @ObservationIgnored
    private let subscriptions = SubscriptionBag()

    @ObservationIgnored
    private var isObserving = false

    init(
        roomID         : String,
        settingsService: any RoomSettingsServiceProtocol
    ) {
        self.roomID = roomID
        self.settingsService = settingsService
    }

    /// Loads the current snapshot and starts observing the room for later changes, e.g. from
    /// another device editing the same room concurrently.
    func start() async {
        observeIfNeeded()
        await refresh()
    }

    /// Sends every non nil field in `draft` to the homeserver, one request per field, stopping at
    /// the first failure so the screen can tell exactly which change did not take.
    func apply(_ draft: RoomMetadataDraft) async {
        await perform {
            if let name = draft.name {
                try await self.settingsService.rename(name, roomID: self.roomID)
            }

            if let topic = draft.topic {
                try await self.settingsService.setTopic(topic, roomID: self.roomID)
            }

            if let joinRule = draft.joinRule {
                try await self.settingsService.updateJoinRule(joinRule, roomID: self.roomID)
            }

            if let historyVisibility = draft.historyVisibility {
                try await self.settingsService.updateHistoryVisibility(historyVisibility, roomID: self.roomID)
            }

            if let visibility = draft.visibility {
                try await self.settingsService.updateRoomVisibility(visibility, roomID: self.roomID)
            }

            if let canonicalAlias = draft.canonicalAlias {
                try await self.settingsService.updateCanonicalAlias(canonicalAlias, roomID: self.roomID)
            }
        }
    }

    /// Replaces the room avatar. Kept outside `apply(_:)` because it carries binary data rather
    /// than a metadata field.
    func setAvatar(
        data    : Data,
        mimeType: String
    ) async {

        await perform {
            try await self.settingsService.setAvatar(data: data, mimeType: mimeType, roomID: self.roomID)
        }
    }

    /// Removes the room avatar.
    func removeAvatar() async {
        await perform {
            try await self.settingsService.removeAvatar(roomID: self.roomID)
        }
    }

    /// Turns on end to end encryption for the room. See
    /// `RoomSettingsServiceProtocol.enableEncryption(roomID:)` for why this cannot be undone.
    func enableEncryption() async {
        await perform {
            try await self.settingsService.enableEncryption(roomID: self.roomID)
        }
    }

    /// Changes the account's own display name inside this room only.
    func setOwnDisplayName(_ displayName: String?) async {
        await perform {
            try await self.settingsService.setOwnMemberDisplayName(displayName, roomID: self.roomID)
        }
    }

    /// Releases every subscription this repository and its service own. Called once, when the
    /// screen closes.
    func stop() {
        subscriptions.cancelAll()
        isObserving = false
    }

    private func refresh() async {
        do {
            snapshot = try await settingsService.snapshot(roomID: roomID)
            failure = nil
        } catch {
            record(error)
        }
    }

    private func observeIfNeeded() {
        guard !isObserving else {
            return
        }

        isObserving = true

        do {
            let stream = try settingsService.observeSnapshot(roomID: roomID)

            subscriptions.retain(Task { [weak self] in
                for await snapshot in stream {
                    self?.snapshot = snapshot
                }
            })
        } catch {
            record(error)
        }
    }

    /// Every write goes through here: it toggles `isApplying`, records the outcome, and refreshes
    /// the snapshot afterwards so a change that only partially succeeded still shows the truth.
    private func perform(_ action: () async throws -> Void) async {
        isApplying = true

        do {
            try await action()
            failure = nil
        } catch {
            record(error)
        }

        isApplying = false

        // The refresh is not the request the screen asked for, so a write failure has to outlive it:
        // letting a successful reload clear it would erase the only reason the edit did not take.
        let writeFailure = failure

        await refresh()

        if let writeFailure {
            failure = writeFailure
        }
    }

    private func record(_ error: any Error) {
        let settingsFailure = error as? RoomSettingsFailure ?? .updateFailed(SDKErrorInfo(error))

        Log.roomSettings.error("Room settings request failed: \(String(reflecting: error), privacy: .public)")

        failure = settingsFailure
    }
}
