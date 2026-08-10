//
//  IgnoredUsersRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("IgnoredUsersRepository")
struct IgnoredUsersRepositoryTests {

    @Test("start() observes the ignore list and loads the current one")
    func startLoadsIgnoredUserIDs() async {
        let service = MockIgnoredUsersService()

        service.stubbedIgnoredUserIDs = ["@spammer:example.org"]

        let repository = IgnoredUsersRepository(ignoredUsersService: service)

        await repository.start()

        #expect(repository.ignoredUserIDs == ["@spammer:example.org"])
        #expect(service.startObservingCallCount == 1)
    }

    @Test("a later push update replaces the cached list")
    func laterUpdateReplacesList() async {
        let service = MockIgnoredUsersService()
        let repository = IgnoredUsersRepository(ignoredUsersService: service)

        await repository.start()

        service.ignoredUserIDsContinuation.yield(["@one:example.org", "@two:example.org"])

        await Eventually.isTrue { repository.ignoredUserIDs.count == 2 }

        #expect(repository.ignoredUserIDs == ["@one:example.org", "@two:example.org"])
    }

    @Test("ignore records the call and clears isBusy on success")
    func ignoreClearsBusyOnSuccess() async {
        let service = MockIgnoredUsersService()
        let repository = IgnoredUsersRepository(ignoredUsersService: service)

        await repository.ignore(userID: "@spammer:example.org")

        #expect(service.ignoreCalls == ["@spammer:example.org"])
        #expect(repository.isBusy == false)
        #expect(repository.failure == nil)
    }

    @Test("a failed unignore records the failure")
    func failedUnignoreRecordsFailure() async {
        let service = MockIgnoredUsersService()

        service.writeError = UsersFailure.sdk(Fixtures.sdkErrorInfo())

        let repository = IgnoredUsersRepository(ignoredUsersService: service)

        await repository.unignore(userID: "@spammer:example.org")

        #expect(repository.failure != nil)
    }

    @Test("shutdown releases the service")
    func shutdownReleasesService() {
        let service = MockIgnoredUsersService()
        let repository = IgnoredUsersRepository(ignoredUsersService: service)

        repository.shutdown()

        #expect(service.shutdownCallCount == 1)
    }
}
