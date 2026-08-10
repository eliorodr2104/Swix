//
//  MockClientService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
@testable import Swix


/// A `ClientServiceProtocol` a test fully controls: every result is staged ahead of time, every
/// call is recorded, and `sessionEvents` is a stream the test itself feeds through `emit(_:)`.
///
/// `sdkClient` always reads nil: nothing under `SessionRepository` or `AuthenticationRepository`
/// touches the live SDK client directly, they only ever go through this protocol.
final class MockClientService: ClientServiceProtocol {

    /// Every call this mock received, in order.
    private(set) var calls: [Call] = []

    /// Always nil: no test in this suite reaches for the live SDK client.
    let sdkClient: Client? = nil

    /// Not read by anything under test; settable so a future test can stage it if it ever is.
    var currentSession: UserSession?

    /// Not read by anything under test; settable so a future test can stage it if it ever is.
    var userID: String?

    /// Not read by anything under test; settable so a future test can stage it if it ever is.
    var deviceID: String?

    /// Not read by anything under test; settable so a future test can stage it if it ever is.
    var storeIdentity: SessionStoreIdentity?

    /// Fed by `emit(_:)`, consumed by whoever holds a `SessionRepository` built on this mock.
    let sessionEvents: AsyncStream<SessionEvent>

    /// What `restore(_:storeIdentity:)` hands back, or the error it throws.
    var restoreResult: Result<UserSession, any Error> = .failure(StubError.unconfigured)

    /// What `session()` hands back, or the error it throws.
    var sessionResult: Result<PersistedSession, any Error> = .failure(StubError.unconfigured)

    /// What `logout()` throws. Nil means it succeeds.
    var logoutError: (any Error)?

    private let eventContinuation: AsyncStream<SessionEvent>.Continuation

    /// Shared with another mock when a test needs to see both mocks' calls in one timeline.
    private let log: CallLog?

    /// One case per protocol method this mock can be asked to perform.
    enum Call: Equatable {

        case makeClient
        case makeClientWithStoreIdentity
        case restore
        case session
        case logout
        case discard
        case abandonPendingClient
    }

    /// Thrown by whichever stubbed result a test never configured.
    enum StubError: Error {

        case unconfigured
    }

    /// `log` is only needed by tests that assert ordering across this mock and another one, such
    /// as a persistence service mock racing to be cleared before or after this one discards.
    init(log: CallLog? = nil) {
        self.log = log

        (sessionEvents, eventContinuation) = AsyncStream<SessionEvent>.makeStream(bufferingPolicy: .unbounded)
    }

    /// Pushes an event to whoever is observing `sessionEvents`, standing in for the SDK's own
    /// client delegate.
    func emit(_ event: SessionEvent) {
        eventContinuation.yield(event)
    }

    /// Records the call and always fails: no test in this suite exercises a real client build.
    func makeClient(homeserver: String) async throws -> Client {
        record(.makeClient)

        throw StubError.unconfigured
    }

    /// Records the call and always fails: no test in this suite exercises a real client build.
    func makeClient(
        homeserver   : String,
        storeIdentity: SessionStoreIdentity
    ) async throws -> Client {
        record(.makeClientWithStoreIdentity)

        throw StubError.unconfigured
    }

    /// Records the call and hands back whatever `restoreResult` was staged to.
    func restore(
        _ persisted  : PersistedSession,
        storeIdentity: SessionStoreIdentity
    ) async throws -> UserSession {
        record(.restore)

        return try restoreResult.get()
    }

    /// Records the call and hands back whatever `sessionResult` was staged to.
    func session() throws -> PersistedSession {
        record(.session)

        return try sessionResult.get()
    }

    /// Records the call and throws `logoutError` when a test staged one.
    func logout() async throws {
        record(.logout)

        if let logoutError {
            throw logoutError
        }
    }

    /// Records the call. Nothing to tear down, since this mock never holds a real client.
    func discard() {
        record(.discard)
    }

    /// Records the call. Nothing to tear down, since this mock never holds a real client.
    func abandonPendingClient() {
        record(.abandonPendingClient)
    }

    /// Appends to both `calls` and, when a test wired one in, the shared `log`.
    private func record(_ call: Call) {
        calls.append(call)
        log?.record("clientService.\(call)")
    }
}
