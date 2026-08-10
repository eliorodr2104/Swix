//
//  MockSessionPersistenceService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

@testable import Swix


/// A `SessionPersistenceServiceProtocol` a test fully controls: every result is staged ahead of
/// time and every call is recorded.
final class MockSessionPersistenceService: SessionPersistenceServiceProtocol {

    /// Every call this mock received, in order.
    private(set) var calls: [Call] = []

    /// What `hasStoredAccount` reports. Staged directly, since the real one is a plain lookup.
    var hasStoredAccount = false

    /// What `loadActive()` hands back, or the error it throws.
    var loadActiveResult: Result<PersistedSession?, any Error> = .success(nil)

    /// What `storeIdentity(for:)` hands back, or the error it throws.
    var storeIdentityResult: Result<SessionStoreIdentity?, any Error> = .success(nil)

    /// What `persist(_:storeIdentity:)` throws. Nil means it succeeds.
    var persistError: (any Error)?

    /// Shared with another mock when a test needs to see both mocks' calls in one timeline.
    private let log: CallLog?

    /// One case per protocol method this mock can be asked to perform.
    enum Call: Equatable {

        case loadActive
        case storeIdentity
        case persist
        case clearActive
        case purgeOrphans
    }

    /// `log` is only needed by tests that assert ordering across this mock and another one, such
    /// as a client service mock discarding before this one clears the active account.
    init(log: CallLog? = nil) {
        self.log = log
    }

    /// Records the call and hands back whatever `loadActiveResult` was staged to.
    func loadActive() throws -> PersistedSession? {
        record(.loadActive)

        return try loadActiveResult.get()
    }

    /// Records the call and hands back whatever `storeIdentityResult` was staged to.
    func storeIdentity(for userID: String) throws -> SessionStoreIdentity? {
        record(.storeIdentity)

        return try storeIdentityResult.get()
    }

    /// Records the call and throws `persistError` when a test staged one.
    func persist(
        _ session    : PersistedSession,
        storeIdentity: SessionStoreIdentity
    ) throws {
        record(.persist)

        if let persistError {
            throw persistError
        }
    }

    /// Records the call. There is no real store behind this mock to actually clear.
    func clearActive() {
        record(.clearActive)
    }

    /// Records the call. There is no real store behind this mock to actually purge.
    func purgeOrphans() {
        record(.purgeOrphans)
    }

    /// Appends to both `calls` and, when a test wired one in, the shared `log`.
    private func record(_ call: Call) {
        calls.append(call)
        log?.record("persistenceService.\(call)")
    }
}
