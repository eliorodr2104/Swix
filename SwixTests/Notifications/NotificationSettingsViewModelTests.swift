//
//  NotificationSettingsViewModelTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("NotificationSettingsViewModel")
struct NotificationSettingsViewModelTests {

    @Test("groupChatMode and directChatMode fall back to allMessages before loading")
    func modesDefaultToAllMessages() {
        let service = MockNotificationSettingsService()

        service.defaultModes = [:]

        let repository = NotificationSettingsRepository(settingsService: service)
        let viewModel = NotificationSettingsViewModel(repository: repository)

        #expect(viewModel.groupChatMode == .allMessages)
        #expect(viewModel.directChatMode == .allMessages)
    }

    @Test("setGroupChatMode writes both the encrypted and unencrypted group defaults")
    func setGroupChatModeWritesBothScopes() async {
        let service = MockNotificationSettingsService()
        let repository = NotificationSettingsRepository(settingsService: service)
        let viewModel = NotificationSettingsViewModel(repository: repository)

        await viewModel.setGroupChatMode(.mute)

        let scopes = Set(service.setDefaultModeCalls.map(\.scope))

        #expect(scopes == [.encryptedGroup, .unencryptedGroup])
        #expect(viewModel.groupChatMode == .mute)
    }

    @Test("a settings failure surfaces with a titled, user facing message")
    func failureBecomesUserFacing() async {
        let service = MockNotificationSettingsService()

        service.failureToThrow = NotificationsFailure.settingsUnavailable(Fixtures.sdkErrorInfo(kind: .network))

        let repository = NotificationSettingsRepository(settingsService: service)
        let viewModel = NotificationSettingsViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.failure?.title == "Could not read your notification settings")
        #expect(viewModel.failure?.isRetryable == true)
    }

    @Test("setting(for:) reads through to whatever the repository has loaded for that room")
    func settingForRoomReadsRepository() async {
        let service = MockNotificationSettingsService()

        service.roomsWithRules = ["!room:example.org"]
        service.userDefinedModesByID = ["!room:example.org": .mute]

        let repository = NotificationSettingsRepository(settingsService: service)
        let viewModel = NotificationSettingsViewModel(repository: repository)

        await viewModel.loadRooms(roomIDs: ["!room:example.org"])

        #expect(viewModel.setting(for: "!room:example.org")?.mode == .mute)
        #expect(viewModel.setting(for: "!other:example.org") == nil)
    }
}
