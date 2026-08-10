//
//  SessionMetadataStoreTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing
@testable import Swix


/// Covers reading, writing and clearing the active account, on a `UserDefaults` suite scoped to
/// this test so nothing here touches the app's own preferences.
@Suite("SessionMetadataStore")
final class SessionMetadataStoreTests {

    // A suite name unique per instance keeps every test on its own UserDefaults domain, so
    // nothing here can read state left behind by another test or by the app itself.
    private let suiteName = "hylo.Swix.SessionMetadataStoreTests.\(UUID().uuidString)"

    private lazy var defaults = UserDefaults(suiteName: suiteName)!

    private lazy var store = SessionMetadataStore(defaults: defaults)

    // Torn down through a fresh UserDefaults rather than the lazy one above: deinit runs outside the
    // main actor, and removing a named domain works from any instance.
    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @Test("activeUserID is nil before anything was ever stored")
    func activeUserIDStartsNil() {
        #expect(store.activeUserID == nil)
    }

    @Test("setting activeUserID persists it, readable back from the same store")
    func settingActiveUserIDPersists() {
        store.activeUserID = "@alice:example.org"

        #expect(store.activeUserID == "@alice:example.org")
    }

    @Test("setting activeUserID again overwrites the previous value")
    func settingActiveUserIDTwiceOverwrites() {
        store.activeUserID = "@alice:example.org"
        store.activeUserID = "@bob:example.org"

        #expect(store.activeUserID == "@bob:example.org")
    }

    @Test("setting activeUserID to nil clears it, same as clear()")
    func settingActiveUserIDToNilClearsIt() {
        store.activeUserID = "@alice:example.org"
        store.activeUserID = nil

        #expect(store.activeUserID == nil)
    }

    @Test("clear forgets the active account")
    func clearForgetsTheActiveAccount() {
        store.activeUserID = "@alice:example.org"

        store.clear()

        #expect(store.activeUserID == nil)
    }

    @Test("clear on a store that never had an active account does not throw or crash")
    func clearWithNothingStoredIsHarmless() {
        store.clear()

        #expect(store.activeUserID == nil)
    }
}
