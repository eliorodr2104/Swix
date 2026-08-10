//
//  ClientServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Owns the one live SDK `Client` and everything bound to its lifetime.
///
/// A single client serves the whole app, from the moment authentication starts to the moment the
/// user signs out: rebuilding it after login would leave the device keys behind in the store the
/// login created, and a homeserver never lets a device replace the keys it already published.
protocol ClientServiceProtocol {

    /// The live client. SERVICE LAYER ONLY: sibling feature services reach the SDK through this,
    /// no repository and no view model is ever allowed to touch it.
    var sdkClient: Client? { get }

    /// The account the live client is signed in as, or nil while it has no session yet.
    var currentSession: UserSession? { get }

    /// The Matrix user identifier of the live session.
    var userID: String? { get }

    /// The device identifier of the live session.
    var deviceID: String? { get }

    /// Where the live client keeps its stores, needed to persist the account after a login.
    var storeIdentity: SessionStoreIdentity? { get }

    /// Client wide events, mapped out of the SDK delegate. Never finishes while the app runs.
    var sessionEvents: AsyncStream<SessionEvent> { get }

    /// Builds a client for a brand new account and keeps it as the live one.
    ///
    /// Returns the SDK client so the authentication service can drive the login flow on it, which
    /// is the same service layer only escape hatch as `sdkClient`.
    @discardableResult
    func makeClient(homeserver: String) async throws -> Client

    /// Builds a client on the stores of an account we already know.
    ///
    /// This is how a softly logged out account signs back in: reusing its store identity keeps
    /// the crypto store, so the device stays verified and the history stays readable.
    @discardableResult
    func makeClient(
        homeserver   : String,
        storeIdentity: SessionStoreIdentity
    ) async throws -> Client

    /// Builds a client for a stored session and hands the session back to it.
    @discardableResult
    func restore(
        _ persisted  : PersistedSession,
        storeIdentity: SessionStoreIdentity
    ) async throws -> UserSession

    /// Reads back the live session, tokens included, so that it can be persisted.
    func session() throws -> PersistedSession

    /// Ends the session on the homeserver and drops the live client, if there is one.
    func logout() async throws

    /// Drops the live client and its subscriptions, leaving everything on disk untouched.
    func discard()

    /// Drops a client whose login never completed, and deletes the directories it created.
    ///
    /// Nothing is deleted when the client was built on the stores of a known account, so calling
    /// this after an abandoned re-authentication is safe.
    func abandonPendingClient()
}
