//
//  PersistedSessionMapperTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Testing
@testable import Swix


/// Covers the round trip between the SDK's `Session`, the `PersistedSession` DTO and the
/// `UserSession` the app displays, in both directions.
@Suite("PersistedSessionMapper")
struct PersistedSessionMapperTests {

    @Test("an SDK Session round trips through makePersistedSession and back through makeSession")
    func sdkSessionRoundTrips() {
        let sdkSession = Session(
            accessToken       : "access-token",
            refreshToken      : "refresh-token",
            userId            : "@alice:example.org",
            deviceId          : "DEVICE1",
            homeserverUrl     : "https://example.org",
            oauthData         : nil,
            slidingSyncVersion: .native
        )

        let persisted = PersistedSessionMapper.makePersistedSession(from: sdkSession)
        let roundTripped = PersistedSessionMapper.makeSession(from: persisted)

        #expect(roundTripped == sdkSession)
    }

    @Test("a stored DTO round trips through makeSession and back through makePersistedSession")
    func persistedSessionRoundTrips() {
        let persisted = Fixtures.persistedSession(
            refreshToken      : "refresh-token",
            oauthData         : "oauth-blob",
            slidingSyncVersion: "native"
        )

        let sdkSession = PersistedSessionMapper.makeSession(from: persisted)
        let roundTripped = PersistedSessionMapper.makePersistedSession(from: sdkSession)

        #expect(roundTripped == persisted)
    }

    @Test("a sliding sync version of 'none' round trips instead of silently upgrading to native")
    func noneSlidingSyncVersionRoundTrips() {
        let persisted = Fixtures.persistedSession(slidingSyncVersion: "none")

        let sdkSession = PersistedSessionMapper.makeSession(from: persisted)

        #expect(sdkSession.slidingSyncVersion == .none)

        let roundTripped = PersistedSessionMapper.makePersistedSession(from: sdkSession)

        #expect(roundTripped.slidingSyncVersion == "none")
    }

    @Test("an unrecognized stored sliding sync name falls back to none rather than crashing")
    func unrecognizedSlidingSyncNameFallsBackToNone() {
        let persisted = Fixtures.persistedSession(slidingSyncVersion: "some-future-version")

        let sdkSession = PersistedSessionMapper.makeSession(from: persisted)

        #expect(sdkSession.slidingSyncVersion == .none)
    }

    @Test("makeUserSession strips every secret, keeping only what the app displays")
    func makeUserSessionStripsSecrets() {
        let persisted = Fixtures.persistedSession(
            userID       : "@alice:example.org",
            deviceID     : "DEVICE1",
            homeserverURL: "https://example.org",
            oauthData    : nil
        )

        let userSession = PersistedSessionMapper.makeUserSession(from: persisted)

        #expect(userSession.userID == "@alice:example.org")
        #expect(userSession.deviceID == "DEVICE1")
        #expect(userSession.homeserverURL == "https://example.org")
        #expect(userSession.usedOAuth == false)
    }

    @Test("makeUserSession reports usedOAuth whenever oauthData was present")
    func makeUserSessionReportsOAuthUsage() {
        let persisted = Fixtures.persistedSession(oauthData: "oauth-blob")

        let userSession = PersistedSessionMapper.makeUserSession(from: persisted)

        #expect(userSession.usedOAuth)
    }
}
