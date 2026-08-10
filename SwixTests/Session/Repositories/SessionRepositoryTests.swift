//
//  SessionRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


/// Covers `SessionRepository`'s restore path, its reaction to a soft and a hard auth error, and
/// the ordering `signOut` guarantees between the homeserver call and the local wipe.
@Suite("SessionRepository")
struct SessionRepositoryTests {

    // MARK: restoreIfPossible

    @Test("restoring with nothing stored purges orphans and settles on loggedOut")
    func restoreWithNothingStoredSettlesOnLoggedOut() async {
        let clientService = MockClientService()
        let persistenceService = MockSessionPersistenceService()
        let repository = SessionRepository(
            clientService     : clientService,
            persistenceService: persistenceService
        )

        await repository.restoreIfPossible()

        #expect(repository.state == .loggedOut)
        #expect(persistenceService.calls.contains(.purgeOrphans))
        #expect(persistenceService.calls.contains(.loadActive))
        #expect(clientService.calls.isEmpty)
    }

    @Test("restoring a known account hands the session to the client service and authenticates")
    func restoringAKnownAccountAuthenticates() async {
        let clientService = MockClientService()
        let persistenceService = MockSessionPersistenceService()

        let persisted = Fixtures.persistedSession()
        let identity = Fixtures.storeIdentity()
        let restoredSession = Fixtures.userSession()

        persistenceService.loadActiveResult = .success(persisted)
        persistenceService.storeIdentityResult = .success(identity)
        clientService.restoreResult = .success(restoredSession)

        let repository = SessionRepository(
            clientService     : clientService,
            persistenceService: persistenceService
        )

        await repository.restoreIfPossible()

        #expect(repository.state == .authenticated(restoredSession))
        #expect(clientService.calls == [.restore])
    }

    @Test("a restore that fails keeps the stored credentials, only marking the account loggedOut")
    func aFailingRestoreKeepsTheCredentials() async {
        let clientService = MockClientService()
        let persistenceService = MockSessionPersistenceService()

        persistenceService.loadActiveResult = .success(Fixtures.persistedSession())
        persistenceService.storeIdentityResult = .success(Fixtures.storeIdentity())
        clientService.restoreResult = .failure(SessionFailure.noActiveClient)

        let repository = SessionRepository(
            clientService     : clientService,
            persistenceService: persistenceService
        )

        await repository.restoreIfPossible()

        #expect(repository.state == .loggedOut)
        #expect(repository.failure != nil)
        #expect(!persistenceService.calls.contains(.clearActive))
    }

    @Test("restoring twice while already authenticated only touches the stores once")
    func restoringTwiceWhileAuthenticatedIsIdempotent() async {
        let clientService = MockClientService()
        let persistenceService = MockSessionPersistenceService()

        persistenceService.loadActiveResult = .success(Fixtures.persistedSession())
        persistenceService.storeIdentityResult = .success(Fixtures.storeIdentity())
        clientService.restoreResult = .success(Fixtures.userSession())

        let repository = SessionRepository(
            clientService     : clientService,
            persistenceService: persistenceService
        )

        await repository.restoreIfPossible()
        let callsAfterFirstRestore = persistenceService.calls.count

        await repository.restoreIfPossible()

        #expect(persistenceService.calls.count == callsAfterFirstRestore)
        #expect(clientService.calls == [.restore])
    }

    // MARK: Soft logout

    @Test("a soft logout discards the live client but keeps the local data and the account")
    func softLogoutDiscardsTheClientButKeepsTheAccount() async {
        let clientService = MockClientService()
        let persistenceService = MockSessionPersistenceService()

        let userSession = Fixtures.userSession()

        persistenceService.loadActiveResult = .success(Fixtures.persistedSession())
        persistenceService.storeIdentityResult = .success(Fixtures.storeIdentity())
        clientService.restoreResult = .success(userSession)

        let repository = SessionRepository(
            clientService     : clientService,
            persistenceService: persistenceService
        )

        await repository.restoreIfPossible()

        clientService.emit(.authenticationExpired(isSoftLogout: true))

        await Eventually.isTrue { repository.state != .authenticated(userSession) }

        #expect(repository.state == .softLoggedOut(userSession))
        #expect(clientService.calls.last == .discard)
        #expect(!persistenceService.calls.contains(.clearActive))
    }

    // MARK: Hard logout ordering

    @Test("a hard auth error discards the client before clearing the stored credentials")
    func hardAuthErrorDiscardsBeforeClearing() async {
        let log = CallLog()
        let clientService = MockClientService(log: log)
        let persistenceService = MockSessionPersistenceService(log: log)

        let userSession = Fixtures.userSession()

        persistenceService.loadActiveResult = .success(Fixtures.persistedSession())
        persistenceService.storeIdentityResult = .success(Fixtures.storeIdentity())
        clientService.restoreResult = .success(userSession)

        let repository = SessionRepository(
            clientService     : clientService,
            persistenceService: persistenceService
        )

        await repository.restoreIfPossible()

        clientService.emit(.authenticationExpired(isSoftLogout: false))

        await Eventually.isTrue { repository.state == .loggedOut }

        #expect(repository.state == .loggedOut)

        let discardIndex = log.entries.firstIndex(of: "clientService.discard")
        let clearIndex = log.entries.firstIndex(of: "persistenceService.clearActive")

        #expect(discardIndex != nil)
        #expect(clearIndex != nil)

        if let discardIndex, let clearIndex {
            #expect(discardIndex < clearIndex)
        }
    }

    // MARK: signOut ordering

    @Test("signing out logs out on the homeserver, then discards, then clears the local data")
    func signOutOrdersLogoutDiscardAndClear() async {
        let log = CallLog()
        let clientService = MockClientService(log: log)
        let persistenceService = MockSessionPersistenceService(log: log)

        let repository = SessionRepository(
            clientService     : clientService,
            persistenceService: persistenceService
        )

        await repository.signOut()

        #expect(repository.state == .loggedOut)
        #expect(repository.failure == nil)
        #expect(log.entries == [
            "clientService.logout",
            "clientService.discard",
            "persistenceService.clearActive"
        ])
    }

    @Test("a homeserver that refuses the logout still discards and clears the local data")
    func signOutStillClearsLocallyWhenTheHomeserverRefuses() async {
        let log = CallLog()
        let clientService = MockClientService(log: log)
        let persistenceService = MockSessionPersistenceService(log: log)

        clientService.logoutError = SessionFailure.noActiveClient

        let repository = SessionRepository(
            clientService     : clientService,
            persistenceService: persistenceService
        )

        await repository.signOut()

        #expect(repository.state == .loggedOut)
        #expect(repository.failure != nil)
        #expect(log.entries == [
            "clientService.logout",
            "clientService.discard",
            "persistenceService.clearActive"
        ])
    }
}
