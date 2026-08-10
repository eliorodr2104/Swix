//
//  RoomSettingsViewModel.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Observation


/// Everything a room settings screen binds to: the current snapshot, whether a change is in
/// flight, and what to say when one fails.
@Observable
final class RoomSettingsViewModel {

    /// The failure to present. Views clear it by setting it back to nil.
    var failure: UserFacingFailure?

    @ObservationIgnored
    private let repository: RoomSettingsRepository

    init(repository: RoomSettingsRepository) {
        self.repository = repository
    }

    /// The room's settings as of the last load or push update.
    var snapshot: RoomSettingsSnapshot? {
        repository.snapshot
    }

    /// Whether a change is currently being sent, so the screen can disable its controls.
    var isApplying: Bool {
        repository.isApplying
    }

    /// Loads the screen. Called when it appears for the first time.
    func start() async {
        await repository.start()
        updateFailure()
    }

    /// Tears the screen down when it closes.
    func stop() {
        repository.stop()
    }

    /// Renames the room.
    func rename(to name: String) async {
        await apply(RoomMetadataDraft(name: name))
    }

    /// Sets the room's topic.
    func setTopic(_ topic: String) async {
        await apply(RoomMetadataDraft(topic: topic))
    }

    /// Changes who is allowed to join the room without an invite.
    func updateJoinRule(_ joinRule: JoinRuleSetting) async {
        await apply(RoomMetadataDraft(joinRule: joinRule))
    }

    /// Changes how far back new members can read the room's history.
    func updateHistoryVisibility(_ visibility: HistoryVisibilitySetting) async {
        await apply(RoomMetadataDraft(historyVisibility: visibility))
    }

    /// Publishes or unpublishes the room from the homeserver's public room directory.
    func updateRoomVisibility(_ visibility: RoomVisibilitySetting) async {
        await apply(RoomMetadataDraft(visibility: visibility))
    }

    /// Replaces the room's canonical alias and alternates together.
    func updateCanonicalAlias(_ edit: CanonicalAliasEdit) async {
        await apply(RoomMetadataDraft(canonicalAlias: edit))
    }

    /// Replaces the room avatar with already loaded image data.
    func setAvatar(
        data    : Data,
        mimeType: String
    ) async {

        await repository.setAvatar(data: data, mimeType: mimeType)
        updateFailure()
    }

    /// Removes the room avatar.
    func removeAvatar() async {
        await repository.removeAvatar()
        updateFailure()
    }

    /// Turns on end to end encryption for the room. Irreversible, see
    /// `RoomSettingsServiceProtocol.enableEncryption(roomID:)`.
    func enableEncryption() async {
        await repository.enableEncryption()
        updateFailure()
    }

    /// Changes the account's own display name inside this room only.
    func setOwnDisplayName(_ displayName: String?) async {
        await repository.setOwnDisplayName(displayName)
        updateFailure()
    }

    private func apply(_ draft: RoomMetadataDraft) async {
        await repository.apply(draft)
        updateFailure()
    }

    private func updateFailure() {
        guard let repositoryFailure = repository.failure else {
            failure = nil
            return
        }

        failure = Self.makeUserFacingFailure(from: repositoryFailure)
    }

    private static func makeUserFacingFailure(from failure: RoomSettingsFailure) -> UserFacingFailure {
        UserFacingFailure(
            title      : title(for: failure),
            message    : failure.message,
            isRetryable: failure.isRetryable
        )
    }

    private static func title(for failure: RoomSettingsFailure) -> String {
        switch failure {
            case .noActiveClient: "You are signed out"
            case .roomUnavailable: "That chat is gone"
            case .updateFailed: "Something went wrong"
            case .snapshotUnavailable: "Could not load room settings"
        }
    }
}
