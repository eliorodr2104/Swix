//
//  RoomSettingsViewModelTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("RoomSettingsViewModel")
struct RoomSettingsViewModelTests {

    @Test("rename builds a draft touching only the name")
    func renameBuildsNameOnlyDraft() async {
        let service = MockRoomSettingsService()
        let repository = RoomSettingsRepository(roomID: "!room:example.org", settingsService: service)
        let viewModel = RoomSettingsViewModel(repository: repository)

        await viewModel.rename(to: "New name")

        #expect(service.renameCalls == ["New name"])
        #expect(service.setTopicCalls.isEmpty)
    }

    @Test("start() exposes the loaded snapshot")
    func startExposesSnapshot() async {
        let service = MockRoomSettingsService()
        let repository = RoomSettingsRepository(roomID: "!room:example.org", settingsService: service)
        let viewModel = RoomSettingsViewModel(repository: repository)

        await viewModel.start()

        #expect(viewModel.snapshot?.roomID == "!room:example.org")
    }

    @Test("a failure surfaces with a titled, user facing message")
    func failureBecomesUserFacing() async {
        let service = MockRoomSettingsService()

        service.failingCall = .rename

        let repository = RoomSettingsRepository(roomID: "!room:example.org", settingsService: service)
        let viewModel = RoomSettingsViewModel(repository: repository)

        await viewModel.rename(to: "New name")

        #expect(viewModel.failure?.title == "Something went wrong")
    }

    @Test("stop tears down the repository's observation")
    func stopTearsDownRepository() {
        let service = MockRoomSettingsService()
        let repository = RoomSettingsRepository(roomID: "!room:example.org", settingsService: service)
        let viewModel = RoomSettingsViewModel(repository: repository)

        viewModel.stop()
    }
}
