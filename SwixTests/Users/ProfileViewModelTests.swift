//
//  ProfileViewModelTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing
@testable import Swix


@Suite("ProfileViewModel")
struct ProfileViewModelTests {

    @Test("start() seeds the editable field from the loaded profile")
    func startSeedsDisplayNameField() async {
        let service = MockProfileService()

        service.stubbedOwnProfile = UserProfileInfo(userID: "@alice:example.org", displayName: "Alice", avatarURL: nil, status: nil, isInCall: false)

        let repository = OwnProfileRepository(profileService: service)
        let viewModel = ProfileViewModel(repository: repository)

        await viewModel.start()

        #expect(viewModel.displayNameText == "Alice")
    }

    @Test("saveDisplayName ignores an attempt to save a blank name")
    func saveDisplayNameIgnoresBlankName() async {
        let service = MockProfileService()
        let repository = OwnProfileRepository(profileService: service)
        let viewModel = ProfileViewModel(repository: repository)

        viewModel.displayNameText = "   "

        await viewModel.saveDisplayName()

        #expect(service.setDisplayNameCalls.isEmpty)
    }

    @Test("saveDisplayName trims whitespace before sending it")
    func saveDisplayNameTrimsWhitespace() async {
        let service = MockProfileService()
        let repository = OwnProfileRepository(profileService: service)
        let viewModel = ProfileViewModel(repository: repository)

        viewModel.displayNameText = "  Alice  "

        await viewModel.saveDisplayName()

        #expect(service.setDisplayNameCalls == ["Alice"])
    }

    @Test("a failure is surfaced with a titled, user facing message")
    func failureBecomesUserFacing() async {
        let service = MockProfileService()

        service.writeError = UsersFailure.sdk(Fixtures.sdkErrorInfo(kind: .network))

        let repository = OwnProfileRepository(profileService: service)
        let viewModel = ProfileViewModel(repository: repository)

        viewModel.displayNameText = "Alice"

        await viewModel.saveDisplayName()

        #expect(viewModel.failure?.title == "Something went wrong")
        #expect(viewModel.failure?.isRetryable == true)
    }
}
