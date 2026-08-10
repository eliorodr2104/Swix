//
//  AuthenticationFlowTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


/// Covers every combination `AuthenticationFlow.preferred(for:)` has to decide between: password
/// only, OAuth only, both offered, and neither.
@Suite("AuthenticationFlow.preferred")
struct AuthenticationFlowTests {

    @Test("a homeserver offering only password login shows the password form")
    func passwordOnlySelectsPassword() {
        let methods = Fixtures.loginMethods(
            supportsPassword: true,
            supportsOAuth   : false
        )

        #expect(AuthenticationFlow.preferred(for: methods) == .password)
    }

    @Test("a homeserver offering only OAuth opens the OAuth sheet")
    func oauthOnlySelectsOAuth() {
        let methods = Fixtures.loginMethods(
            supportsPassword: false,
            supportsOAuth   : true
        )

        #expect(AuthenticationFlow.preferred(for: methods) == .oauth)
    }

    @Test("a homeserver offering both flows prefers OAuth, since matrix.org treats password as legacy")
    func bothFlowsPrefersOAuth() {
        let methods = Fixtures.loginMethods(
            supportsPassword: true,
            supportsOAuth   : true
        )

        #expect(AuthenticationFlow.preferred(for: methods) == .oauth)
    }

    @Test("a homeserver offering neither flow is unsupported")
    func neitherFlowIsUnsupported() {
        let methods = Fixtures.loginMethods(
            supportsPassword: false,
            supportsOAuth   : false
        )

        #expect(AuthenticationFlow.preferred(for: methods) == .unsupported)
    }

    @Test("a homeserver with no sliding sync is unsupported no matter what it offers to log in with")
    func noSlidingSyncIsAlwaysUnsupported() {
        let methods = Fixtures.loginMethods(
            supportsPassword  : true,
            supportsOAuth     : true,
            slidingSyncVersion: .unsupported
        )

        #expect(AuthenticationFlow.preferred(for: methods) == .unsupported)
    }
}
