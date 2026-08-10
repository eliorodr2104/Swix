//
//  MockInertClientService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
@testable import Swix


/// A `ClientServiceProtocol` that never has a live client, shared by every suite whose subject only
/// needs the protocol to exist rather than to answer.
///
/// Two kinds of test lean on it. `UserSessionScopeTests` builds a whole scope the way `CoreContainer`
/// would once a session turns authenticated: every feature service the scope assembles reads
/// `sdkClient` lazily, when a screen actually calls one of its operations, so standing the scope up on
/// top of this touches nothing. The Users suites push `ProfileService`, `PresenceService` and
/// `IgnoredUsersService` as far as they go without a homeserver, which is exactly up to the point where
/// each of them reads `sdkClient` and gives up.
final class MockInertClientService: ClientServiceProtocol {

    /// Always nil, which is the whole point of this mock.
    var sdkClient: Client?

    /// Settable so a test can stage it, though nothing built on this mock reads it.
    var currentSession: UserSession?

    /// Settable so a test can stage it, though nothing built on this mock reads it.
    var userID: String?

    /// Settable so a test can stage it, though nothing built on this mock reads it.
    var deviceID: String?

    /// Settable so a test can stage it, though nothing built on this mock reads it.
    var storeIdentity: SessionStoreIdentity?

    /// A stream that stays silent unless a test feeds it through `sessionEventContinuation`.
    let sessionEvents: AsyncStream<SessionEvent>

    /// Exposed rather than private so a test can push a session event without another helper.
    let sessionEventContinuation: AsyncStream<SessionEvent>.Continuation

    init() {
        (sessionEvents, sessionEventContinuation) = AsyncStream<SessionEvent>.makeStream(bufferingPolicy: .unbounded)
    }

    /// Traps: building a real client needs a homeserver, which no suite using this mock has.
    func makeClient(homeserver: String) async throws -> Client {
        fatalError("not exercised by these tests")
    }

    /// Traps: building a real client needs a homeserver, which no suite using this mock has.
    func makeClient(
        homeserver   : String,
        storeIdentity: SessionStoreIdentity
    ) async throws -> Client {
        fatalError("not exercised by these tests")
    }

    /// Traps: restoring a session would have to produce a real client.
    func restore(
        _ persisted  : PersistedSession,
        storeIdentity: SessionStoreIdentity
    ) async throws -> UserSession {
        fatalError("not exercised by these tests")
    }

    /// Traps: there is no client to read a persisted session out of.
    func session() throws -> PersistedSession {
        fatalError("not exercised by these tests")
    }

    /// Succeeds silently, so a teardown path can run without a client.
    func logout() async throws {}

    /// Succeeds silently, so a teardown path can run without a client.
    func discard() {}

    /// Succeeds silently, so a teardown path can run without a client.
    func abandonPendingClient() {}
}
