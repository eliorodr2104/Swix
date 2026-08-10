//
//  NotificationSettingsRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("NotificationSettingsRepository")
struct NotificationSettingsRepositoryTests {

    @Test("load() reads the four defaults and the four global toggles")
    func loadReadsGlobals() async {
        let service = MockNotificationSettingsService()

        service.defaultModes[.encryptedGroup] = .mentionsAndKeywords
        service.isCallEnabledValue = false

        let repository = NotificationSettingsRepository(settingsService: service)

        await repository.load()

        #expect(repository.defaultModes[.encryptedGroup] == .mentionsAndKeywords)
        #expect(repository.isCallEnabled == false)
        #expect(repository.failure == nil)
        #expect(repository.isLoading == false)
    }

    @Test("load(roomIDs:) only keeps the rooms that carry their own rule")
    func loadRoomIDsFiltersRuledRooms() async {
        let service = MockNotificationSettingsService()

        service.roomsWithRules = ["!ruled:example.org"]
        service.userDefinedModesByID = ["!ruled:example.org": .mute]

        let repository = NotificationSettingsRepository(settingsService: service)

        await repository.load(roomIDs: ["!ruled:example.org", "!default:example.org"])

        #expect(repository.roomSettings["!ruled:example.org"] == RoomNotificationSetting(mode: .mute, isDefault: false))
        #expect(repository.roomSettings["!default:example.org"] == nil)
    }

    @Test("load(roomIDs:) drops a cached room that no longer carries a rule")
    func loadRoomIDsDropsStaleRule() async {
        let service = MockNotificationSettingsService()

        service.roomsWithRules = ["!room:example.org"]
        service.userDefinedModesByID = ["!room:example.org": .mute]

        let repository = NotificationSettingsRepository(settingsService: service)

        await repository.load(roomIDs: ["!room:example.org"])

        #expect(repository.roomSettings["!room:example.org"] != nil)

        service.roomsWithRules = []

        await repository.load(roomIDs: ["!room:example.org"])

        #expect(repository.roomSettings["!room:example.org"] == nil)
    }

    @Test("setMode writes the room's mode only after the homeserver confirms it")
    func setModeUpdatesCacheAfterConfirmation() async {
        let service = MockNotificationSettingsService()
        let repository = NotificationSettingsRepository(settingsService: service)

        await repository.setMode(roomID: "!room:example.org", mode: .mute)

        #expect(service.setModeCalls.count == 1)
        #expect(repository.roomSettings["!room:example.org"] == RoomNotificationSetting(mode: .mute, isDefault: false))
    }

    @Test("restoreDefaultMode drops the room's cached override")
    func restoreDefaultDropsOverride() async {
        let service = MockNotificationSettingsService()
        let repository = NotificationSettingsRepository(settingsService: service)

        await repository.setMode(roomID: "!room:example.org", mode: .mute)
        await repository.restoreDefaultMode(roomID: "!room:example.org")

        #expect(repository.roomSettings["!room:example.org"] == nil)
        #expect(service.restoreDefaultCalls == ["!room:example.org"])
    }

    @Test("a failure is recorded and does not corrupt already loaded state")
    func failureIsRecorded() async {
        let service = MockNotificationSettingsService()

        service.failureToThrow = NotificationsFailure.updateFailed(Fixtures.sdkErrorInfo())

        let repository = NotificationSettingsRepository(settingsService: service)

        await repository.setMode(roomID: "!room:example.org", mode: .mute)

        #expect(repository.failure != nil)
        #expect(repository.roomSettings["!room:example.org"] == nil)
    }

    @Test("a remote settings change refreshes the globals and the cached rooms")
    func remoteChangeRefreshesState() async {
        let service = MockNotificationSettingsService()
        let repository = NotificationSettingsRepository(settingsService: service)

        service.roomsWithRules = ["!room:example.org"]
        service.userDefinedModesByID = ["!room:example.org": .mentionsAndKeywords]

        await repository.load(roomIDs: ["!room:example.org"])

        #expect(repository.roomSettings["!room:example.org"]?.mode == .mentionsAndKeywords)

        // Another device changes the rule; the settings changed stream is what should pick it up.
        service.userDefinedModesByID["!room:example.org"] = .mute
        service.defaultModes[.encryptedGroup] = .mute

        service.changeContinuation.yield(())

        await Eventually.isTrue { repository.roomSettings["!room:example.org"]?.mode == .mute }

        #expect(repository.defaultModes[.encryptedGroup] == .mute)
    }

    @Test("shutdown releases the service")
    func shutdownReleasesService() {
        let service = MockNotificationSettingsService()
        let repository = NotificationSettingsRepository(settingsService: service)

        repository.shutdown()

        #expect(service.shutdownCallCount == 1)
    }
}
