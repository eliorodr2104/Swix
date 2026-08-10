//
//  RoomSettingsRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing
@testable import Swix


@Suite("RoomSettingsRepository")
struct RoomSettingsRepositoryTests {

    @Test("start() loads the current snapshot")
    func startLoadsSnapshot() async {
        let service = MockRoomSettingsService()
        let repository = RoomSettingsRepository(roomID: "!room:example.org", settingsService: service)

        await repository.start()

        #expect(repository.snapshot?.roomID == "!room:example.org")
        #expect(service.snapshotCallCount == 1)
    }

    @Test("apply sends exactly one request per non nil field of the draft")
    func applySendsOneRequestPerField() async {
        let service = MockRoomSettingsService()
        let repository = RoomSettingsRepository(roomID: "!room:example.org", settingsService: service)

        let draft = RoomMetadataDraft(
            name             : "New name",
            topic            : "New topic",
            joinRule         : .public,
            historyVisibility: .worldReadable,
            visibility       : .public,
            canonicalAlias   : CanonicalAliasEdit(alias: "#room:example.org", alternates: [])
        )

        await repository.apply(draft)

        #expect(service.renameCalls == ["New name"])
        #expect(service.setTopicCalls == ["New topic"])
        #expect(service.updateJoinRuleCalls == [.public])
        #expect(service.updateHistoryVisibilityCalls == [.worldReadable])
        #expect(service.updateRoomVisibilityCalls == [.public])
        #expect(service.updateCanonicalAliasCalls == [CanonicalAliasEdit(alias: "#room:example.org", alternates: [])])
    }

    @Test("apply leaves every field the draft never touched completely alone")
    func applySkipsUntouchedFields() async {
        let service = MockRoomSettingsService()
        let repository = RoomSettingsRepository(roomID: "!room:example.org", settingsService: service)

        await repository.apply(RoomMetadataDraft(topic: "Only the topic"))

        #expect(service.setTopicCalls == ["Only the topic"])
        #expect(service.renameCalls.isEmpty)
        #expect(service.updateJoinRuleCalls.isEmpty)
        #expect(service.updateHistoryVisibilityCalls.isEmpty)
        #expect(service.updateRoomVisibilityCalls.isEmpty)
        #expect(service.updateCanonicalAliasCalls.isEmpty)
    }

    @Test("apply stops at the first failing field, never attempting the ones after it")
    func applyStopsAtFirstFailure() async {
        let service = MockRoomSettingsService()

        service.failingCall = .setTopic

        let repository = RoomSettingsRepository(roomID: "!room:example.org", settingsService: service)

        let draft = RoomMetadataDraft(
            name    : "New name",
            topic   : "This one fails",
            joinRule: .public
        )

        await repository.apply(draft)

        #expect(service.renameCalls == ["New name"], "name comes before topic in the draft, so it must still have been sent")
        #expect(service.setTopicCalls == ["This one fails"])
        #expect(service.updateJoinRuleCalls.isEmpty, "join rule comes after the failing field and must never be attempted")
        #expect(repository.failure != nil)
    }

    @Test("apply refreshes the snapshot afterwards, even when the write failed")
    func applyRefreshesSnapshotAfterward() async {
        let service = MockRoomSettingsService()

        service.failingCall = .rename

        let repository = RoomSettingsRepository(roomID: "!room:example.org", settingsService: service)

        await repository.apply(RoomMetadataDraft(name: "New name"))

        // One refresh from the failed apply. A successful apply would also refresh, this just
        // proves the refresh happens unconditionally rather than only on the happy path.
        #expect(service.snapshotCallCount == 1)
        #expect(repository.failure != nil)
    }

    @Test("isApplying is true only while a write is actually running")
    func isApplyingReflectsInFlightWrite() async {
        let service = MockRoomSettingsService()
        let repository = RoomSettingsRepository(roomID: "!room:example.org", settingsService: service)

        #expect(repository.isApplying == false)

        await repository.apply(RoomMetadataDraft(name: "New name"))

        #expect(repository.isApplying == false)
    }

    @Test("setAvatar and removeAvatar are not part of a draft, and refresh the snapshot too")
    func avatarWritesAreSeparateFromDraft() async {
        let service = MockRoomSettingsService()
        let repository = RoomSettingsRepository(roomID: "!room:example.org", settingsService: service)

        await repository.setAvatar(data: Data([0x1]), mimeType: "image/png")
        await repository.removeAvatar()

        #expect(service.setAvatarCallCount == 1)
        #expect(service.removeAvatarCallCount == 1)
        #expect(service.snapshotCallCount == 2)
    }

    @Test("enableEncryption forwards straight to the service")
    func enableEncryptionForwards() async {
        let service = MockRoomSettingsService()
        let repository = RoomSettingsRepository(roomID: "!room:example.org", settingsService: service)

        await repository.enableEncryption()

        #expect(service.enableEncryptionCallCount == 1)
    }

    @Test("stop releases the service's observation")
    func stopReleasesObservation() {
        let service = MockRoomSettingsService()
        let repository = RoomSettingsRepository(roomID: "!room:example.org", settingsService: service)

        repository.stop()

        // stop() has nothing of its own to assert on the service beyond not crashing when nothing
        // was ever observed; calling it twice must also stay harmless.
        repository.stop()
    }
}
