//
//  AuthenticationRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Observation
import os

/// Orchestrates a login: ask the homeserver what it supports, run the flow it named, then hand the
/// signed in client over to `SessionRepository` so it becomes the app's session.
///
/// The SDK never appears here; the service layer below owns every handle.
@Observable
final class AuthenticationRepository {

    /// What the last discovered homeserver advertised, or nil before any discovery.
    private(set) var loginMethods: HomeserverLoginMethods?

    /// The flow the login screen should present, derived from `loginMethods`.
    private(set) var flow: AuthenticationFlow?

    /// Whether an operation is in flight. Only one runs at a time.
    private(set) var isBusy = false

    /// The last failure, cleared when a new attempt starts.
    private(set) var failure: AuthenticationFailure?

    @ObservationIgnored
    private let authenticationService: any AuthenticationServiceProtocol

    @ObservationIgnored
    private let webAuthenticator: any OAuthWebAuthenticatorProtocol

    @ObservationIgnored
    private let sessionRepository: SessionRepository

    @ObservationIgnored
    private let persistenceService: any SessionPersistenceServiceProtocol

    init(
        authenticationService: any AuthenticationServiceProtocol,
        webAuthenticator     : any OAuthWebAuthenticatorProtocol,
        sessionRepository    : SessionRepository,
        persistenceService   : any SessionPersistenceServiceProtocol
    ) {
        self.authenticationService = authenticationService
        self.webAuthenticator      = webAuthenticator
        self.sessionRepository     = sessionRepository
        self.persistenceService    = persistenceService
    }

    /// Resolves a homeserver and decides which flow the user will be offered.
    func discover(homeserver: String) async {
        let homeserver = homeserver.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !homeserver.isEmpty else {
            return
        }

        await perform {
            let methods = try await self.authenticationService.discover(
                homeserver   : homeserver,
                storeIdentity: self.resolveStoreIdentity()
            )

            self.loginMethods = methods
            self.flow         = AuthenticationFlow.preferred(for: methods)

            guard self.flow != .unsupported else {
                throw AuthenticationFailure.unsupportedLoginFlow
            }
        }
    }

    /// Signs in with a username and a password, then adopts the resulting session.
    func signInWithPassword(
        homeserver : String,
        credentials: PasswordCredentials
    ) async {
    
        await perform {
            try await self.authenticationService.loginWithPassword(
                homeserver   : homeserver,
                storeIdentity: self.resolveStoreIdentity(),
                credentials  : credentials
            )

            try self.sessionRepository.handleAuthenticated()
        }
    }

    /// Runs the whole OAuth round trip, from the authorization page to the adopted session.
    func signInWithOAuth(homeserver: String) async {
        
        await perform {
            let request = try await self.authenticationService.startOAuth(
                homeserver   : homeserver,
                storeIdentity: self.resolveStoreIdentity()
            )

            let callbackURL: URL
            do {
                callbackURL = try await self.webAuthenticator.authenticate(
                    url           : request.authorizationURL,
                    callbackScheme: request.callbackScheme
                )
                
            } catch {
                // The homeserver is holding an authorization open for a user who walked away.
                await self.authenticationService.abortOAuth()

                throw error
            }

            try await self.authenticationService.completeOAuth(callbackURL: callbackURL)
            try self.sessionRepository.handleAuthenticated()
        }
    }

    /// Abandons the login: the pending authorization, the client and the stores it created.
    func cancel() async {
        await authenticationService.cancel()

        loginMethods = nil
        flow         = nil
        failure      = nil
    }

    /// An account that was softly logged out signs back in on its own stores, or its device would
    /// come back with new keys and lose everything it could read before.
    private func resolveStoreIdentity() throws -> SessionStoreIdentity? {
        guard case .softLoggedOut(let userSession) = sessionRepository.state else {
            return nil
        }

        return try persistenceService.storeIdentity(for: userSession.userID)
    }

    private func perform(_ operation: () async throws -> Void) async {
        guard !isBusy else {
            return
        }

        isBusy  = true
        failure = nil

        do {
            try await operation()
            
        } catch { record(error) }

        isBusy = false
    }

    private func record(_ error: any Error) {
        let failure = AuthenticationFailure.wrapping(error)

        if case .oauthCancelledByUser = failure {
            Log.auth.notice("The user closed the sign in sheet")
            
        } else {
            Log.auth.error(
                "Authentication failure: \(String(reflecting: error), privacy: .public)"
            )
        }

        self.failure = failure
    }
}
