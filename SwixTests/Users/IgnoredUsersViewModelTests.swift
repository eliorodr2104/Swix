//
//  IgnoredUsersViewModelTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("IgnoredUsersViewModel")
struct IgnoredUsersViewModelTests {

    @Test("start() reads through to the repository's ignore list")
    func startReadsThroughToRepository() async {
        let service = MockIgnoredUsersService()

        service.stubbedIgnoredUserIDs = ["@spammer:example.org"]

        let repository = IgnoredUsersRepository(ignoredUsersService: service)
        let viewModel = IgnoredUsersViewModel(repository: repository)

        await viewModel.start()

        #expect(viewModel.ignoredUserIDs == ["@spammer:example.org"])
    }

    @Test("ignore forwards to the repository")
    func ignoreForwardsToRepository() async {
        let service = MockIgnoredUsersService()
        let repository = IgnoredUsersRepository(ignoredUsersService: service)
        let viewModel = IgnoredUsersViewModel(repository: repository)

        await viewModel.ignore(userID: "@spammer:example.org")

        #expect(service.ignoreCalls == ["@spammer:example.org"])
    }

    @Test("a failure surfaces with a titled, user facing message")
    func failureBecomesUserFacing() async {
        let service = MockIgnoredUsersService()

        service.writeError = UsersFailure.noActiveClient

        let repository = IgnoredUsersRepository(ignoredUsersService: service)
        let viewModel = IgnoredUsersViewModel(repository: repository)

        await viewModel.ignore(userID: "@spammer:example.org")

        #expect(viewModel.failure?.title == "No signed in account")
        #expect(viewModel.failure?.isRetryable == false)
    }

    @Test("shutdown releases the repository")
    func shutdownReleasesRepository() {
        let service = MockIgnoredUsersService()
        let repository = IgnoredUsersRepository(ignoredUsersService: service)
        let viewModel = IgnoredUsersViewModel(repository: repository)

        viewModel.shutdown()

        #expect(service.shutdownCallCount == 1)
    }
}
