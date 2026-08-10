//
//  SessionKeychainTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing
@testable import Swix


/// Covers the CRUD surface of `SessionKeychain` end to end against the real Security framework,
/// on a keychain service scoped to this suite so nothing here touches the app's own items.
@Suite("SessionKeychain")
final class SessionKeychainTests {

    // Swift Testing builds one instance of the suite per test, so a fresh UUID here means every
    // test gets its own keychain service: no collision with the app's real items, with a test
    // that runs in parallel, or with a previous run that crashed before cleaning up.
    private let keychain = SessionKeychain(service: "hylo.Swix.SessionKeychainTests.\(UUID().uuidString)")

    deinit {
        try? keychain.delete(account: "@alice:example.org")
        try? keychain.delete(account: "@bob:example.org")
    }

    @Test("reading an account that was never saved returns nil")
    func readingUnknownAccountReturnsNil() throws {
        let session = try keychain.session(account: "@nobody:example.org")

        #expect(session == nil)
    }

    @Test("a saved session can be read back unchanged")
    func saveThenReadRoundTrips() throws {
        let session = Fixtures.persistedSession(userID: "@alice:example.org")

        try keychain.save(session)

        #expect(try keychain.session(account: "@alice:example.org") == session)
    }

    @Test("saving again for the same account updates the item instead of duplicating it")
    func savingTwiceUpdatesTheExistingItem() throws {
        let original = Fixtures.persistedSession(
            accessToken: "first-token",
            userID     : "@alice:example.org"
        )

        let updated = Fixtures.persistedSession(
            accessToken: "second-token",
            userID     : "@alice:example.org"
        )

        try keychain.save(original)
        try keychain.save(updated)

        #expect(try keychain.session(account: "@alice:example.org") == updated)
        #expect(try keychain.listAccounts().filter { $0 == "@alice:example.org" }.count == 1)
    }

    @Test("listAccounts reports every account that currently has a stored session")
    func listAccountsReportsEveryStoredAccount() throws {
        try keychain.save(Fixtures.persistedSession(userID: "@alice:example.org"))
        try keychain.save(Fixtures.persistedSession(userID: "@bob:example.org"))

        let accounts = Set(try keychain.listAccounts())

        #expect(accounts.isSuperset(of: ["@alice:example.org", "@bob:example.org"]))
    }

    @Test("deleting an account removes it and leaves others untouched")
    func deleteRemovesOnlyTheGivenAccount() throws {
        try keychain.save(Fixtures.persistedSession(userID: "@alice:example.org"))
        try keychain.save(Fixtures.persistedSession(userID: "@bob:example.org"))

        try keychain.delete(account: "@alice:example.org")

        #expect(try keychain.session(account: "@alice:example.org") == nil)
        #expect(try keychain.session(account: "@bob:example.org") != nil)
    }

    @Test("deleting an account that was never saved is not an error")
    func deletingUnknownAccountDoesNotThrow() throws {
        try keychain.delete(account: "@ghost:example.org")
    }
}
