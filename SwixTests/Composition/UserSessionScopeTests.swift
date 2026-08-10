//
//  UserSessionScopeTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


/// `CoreContainer` is what actually decides when a scope exists, opening one the moment
/// `SessionRepository.state` turns authenticated and closing it the moment it stops being one, but
/// it builds its own `ClientService` and `SessionKeychain` internally with no seam a test can stand
/// in front of. `UserSessionScope` is where that decision's *result* lives: everything session
/// scoped is assembled the instant one is built, from a `UserSession` that only exists once
/// authentication produced one, and released the instant `shutdown()` runs. These tests exercise
/// that object directly, which is as close to the container's own contract as the codebase's
/// dependency injection reaches.
@Suite("UserSessionScope")
struct UserSessionScopeTests {

    @Test("a scope is assembled around the authenticated user session it was built for")
    func scopeIsAssembledAroundUserSession() {
        let clientService = MockInertClientService()
        let userSession = Fixtures.userSession(userID: "@alice:example.org")

        let scope = UserSessionScope(userSession: userSession, clientService: clientService)

        #expect(scope.userSession == userSession)

        scope.shutdown()
    }

    @Test("start() attaches every stack without throwing, even with no live client behind it")
    func startAttachesEveryStackWithoutThrowing() async {
        let clientService = MockInertClientService()
        let scope = UserSessionScope(userSession: Fixtures.userSession(), clientService: clientService)

        // Nothing here should throw or crash: every stack records its own failure internally, per
        // UserSessionScope.start()'s own documentation.
        await scope.start()

        scope.shutdown()
    }

    @Test("a room screen fails cleanly instead of crashing before sync ever attached a room")
    func roomScreenFailsCleanlyBeforeSyncAttaches() async {
        let clientService = MockInertClientService()
        let scope = UserSessionScope(userSession: Fixtures.userSession(), clientService: clientService)

        await #expect(throws: (any Error).self) {
            _ = try await scope.makeChatViewModel(forRoom: "!room:example.org")
        }

        scope.shutdown()
    }

    @Test("shutdown is safe to call more than once, the way a scope torn down twice would be")
    func shutdownIsIdempotent() async {
        let clientService = MockInertClientService()
        let scope = UserSessionScope(userSession: Fixtures.userSession(), clientService: clientService)

        await scope.start()

        scope.shutdown()
        scope.shutdown()
    }

    @Test("releaseRoom is harmless for a room that was never opened")
    func releaseRoomIsHarmlessForUnopenedRoom() {
        let clientService = MockInertClientService()
        let scope = UserSessionScope(userSession: Fixtures.userSession(), clientService: clientService)

        scope.releaseRoom("!never-opened:example.org")

        scope.shutdown()
    }

    @Test("makeThreadListViewModel builds a fresh view model scoped to the requested room")
    func makeThreadListViewModelScopesToRoom() {
        let clientService = MockInertClientService()
        let scope = UserSessionScope(userSession: Fixtures.userSession(), clientService: clientService)

        let viewModel = scope.makeThreadListViewModel(forRoom: "!room:example.org")

        #expect(viewModel.roomID == "!room:example.org")

        scope.shutdown()
    }

    @Test("makeRoomSettingsViewModel builds a fresh repository per call, not a shared one")
    func makeRoomSettingsViewModelBuildsFreshRepository() async {
        let clientService = MockInertClientService()
        let scope = UserSessionScope(userSession: Fixtures.userSession(), clientService: clientService)

        let first = scope.makeRoomSettingsViewModel(forRoom: "!room:example.org")
        let second = scope.makeRoomSettingsViewModel(forRoom: "!room:example.org")

        await first.start()

        // Each call builds its own RoomSettingsRepository, so the failure `first.start()` records
        // (there is no room to look up before sync ever attached one) must not leak into a sibling
        // view model built for the same room a moment later and never started.
        #expect(first.failure != nil)
        #expect(second.failure == nil)

        scope.shutdown()
    }
}
