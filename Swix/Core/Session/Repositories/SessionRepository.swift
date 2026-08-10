//
//  SessionRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation
import os


/// The single source of truth for whether the app has a usable account, and the only writer of
/// `SessionState`.
///
/// Everything else in the Core assumes a session exists; this is the object that decides when it
/// does, reacting both to what the user asks and to what the homeserver says.
@Observable
final class SessionRepository {

    /// Where the app stands right now. Views observe this through `SessionViewModel`.
    private(set) var state: SessionState = .none

    /// The last failure that changed the state, kept until the next attempt clears it.
    private(set) var failure: SessionFailure?

    /// Whether the homeserver took the session away, as opposed to the user leaving on their own.
    ///
    /// Raised on both flavours of remote expiry, cleared by a sign in, a sign out, or the view
    /// acknowledging it. This is what lets the login screen open on a "something went wrong" alert
    /// only when coming back was not the user's idea.
    private(set) var sessionWasRevoked = false

    /// Whether an account is marked active on disk and the restore has not landed anywhere yet.
    ///
    /// The very first frame reads this to choose the splash over the onboarding. It turns false as
    /// soon as the state is terminal, so a failed restore falls through to the sign in instead of
    /// leaving the splash on screen forever.
    var hasStoredAccount: Bool {
        switch state {
            case .none, .restoring: persistenceService.hasStoredAccount
            default               : false
        }
    }

    @ObservationIgnored
    private let clientService: any ClientServiceProtocol

    @ObservationIgnored
    private let persistenceService: any SessionPersistenceServiceProtocol

    @ObservationIgnored
    private let subscriptions = SubscriptionBag()

    init(
        clientService     : any ClientServiceProtocol,
        persistenceService: any SessionPersistenceServiceProtocol
    ) {
        self.clientService      = clientService
        self.persistenceService = persistenceService

        observeSessionEvents()
    }

    /// Brings back the stored account, if there is one, and moves to a terminal state either way.
    ///
    /// Doing nothing when an account is already known is what makes this safe to call from a view
    /// that appears more than once, and from the app entry point at the same time.
    func restoreIfPossible() async {
        guard state.userSession == nil, !state.isRestoring else {
            return
        }

        state   = .restoring
        failure = nil

        persistenceService.purgeOrphans()

        do {
            guard let persisted = try persistenceService.loadActive(),
                  let storeIdentity = try persistenceService.storeIdentity(for: persisted.userID) else {
                state = .loggedOut

                return
            }

            let userSession = try await clientService.restore(
                persisted,
                storeIdentity: storeIdentity
            )

            state = .authenticated(userSession)
        } catch {
            // The stored credentials are left alone on purpose: a restore can fail because the
            // network is down, and wiping them would turn a hiccup into a forced sign in.
            record(error)

            state = .loggedOut
        }
    }

    /// Adopts the client the authentication service has just signed in, and persists it.
    func handleAuthenticated() throws {
        let persisted = try clientService.session()

        guard let storeIdentity = clientService.storeIdentity else {
            throw SessionFailure.noActiveClient
        }

        try persistenceService.persist(
            persisted,
            storeIdentity: storeIdentity
        )

        failure           = nil
        sessionWasRevoked = false
        state             = .authenticated(PersistedSessionMapper.makeUserSession(from: persisted))
    }

    /// Lowers the revocation flag once the user has seen the alert it raised.
    func acknowledgeSessionRevocation() {
        sessionWasRevoked = false
    }

    /// Ends the session on the homeserver and erases every local trace of it.
    ///
    /// The local wipe happens even when the homeserver call fails, otherwise a device with no
    /// connectivity could never get rid of its account.
    func signOut() async {
        do {
            try await clientService.logout()
        } catch {
            record(error)
        }

        sessionWasRevoked = false

        forgetSession()
    }

    /// Releases the subscriptions this repository owns. Called once, by the scope that created it,
    /// when the session ends.
    func shutdown() {
        subscriptions.cancelAll()
    }

    private func observeSessionEvents() {
        let events = clientService.sessionEvents

        subscriptions.retain(Task { [weak self] in
            for await event in events {
                self?.handle(event)
            }
        })
    }

    private func handle(_ event: SessionEvent) {
        switch event {
            case .authenticationExpired(let isSoftLogout):
                handleAuthenticationExpired(isSoftLogout: isSoftLogout)

            case .backgroundTaskFailed(let taskName, let reason):
                Log.session.error("The SDK task \(taskName, privacy: .public) failed: \(reason, privacy: .public)")
        }
    }

    private func handleAuthenticationExpired(isSoftLogout: Bool) {
        guard let userSession = state.userSession else {
            return
        }

        sessionWasRevoked = true

        guard isSoftLogout else {
            forgetSession()

            return
        }

        Log.session.notice("Session softly logged out, the local data is kept")

        clientService.discard()
        state = .softLoggedOut(userSession)
    }

    /// Drops the client before the files it holds open, so nothing is deleted from under it.
    private func forgetSession() {
        clientService.discard()
        persistenceService.clearActive()

        state = .loggedOut
    }

    private func record(_ error: any Error) {
        Log.session.error("Session failure: \(String(reflecting: error), privacy: .public)")

        failure = error as? SessionFailure ?? .sdk(SDKErrorInfo(error))
    }
}
