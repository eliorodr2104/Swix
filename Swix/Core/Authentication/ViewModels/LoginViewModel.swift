//
//  LoginViewModel.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Observation

/// Everything the login screen binds to: the three text fields, which form to show, and what to
/// say when something fails.
@Observable
final class LoginViewModel {

    /// The homeserver the user is signing in to, either a server name or a full URL.
    var homeserverText: String

    /// Bound to the username field, only meaningful in the password flow.
    var username = ""

    /// Bound to the secure field, only meaningful in the password flow.
    var password = ""

    /// The failure to present. Views clear it by setting it back to nil.
    var failure: UserFacingFailure?

    @ObservationIgnored
    private let repository: AuthenticationRepository

    init(
        repository    : AuthenticationRepository,
        homeserverText: String = "matrix.org"
    ) {
        self.repository     = repository
        self.homeserverText = homeserverText
    }

    /// The flow the discovered homeserver wants, or nil while nothing has been discovered yet.
    var availableFlow: AuthenticationFlow? {
        repository.flow
    }

    /// Whether an operation is in flight, which is what disables the whole form.
    var isLoading: Bool {
        repository.isBusy
    }

    /// What the homeserver advertised, for a screen that wants to explain the choice it made.
    var loginMethods: HomeserverLoginMethods? {
        repository.loginMethods
    }

    /// Whether the username and password fields belong on screen.
    var showsPasswordForm: Bool {
        availableFlow == .password
    }

    /// Whether the button that opens the OAuth sheet belongs on screen.
    var showsOAuthButton: Bool {
        availableFlow == .oauth
    }

    /// Whether the discovered homeserver offers nothing Swix can drive.
    var isFlowUnsupported: Bool {
        availableFlow == .unsupported
    }

    /// Whether the homeserver field holds something worth resolving.
    var canDiscover: Bool {
        !isLoading && !homeserverText.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
    }

    /// Whether the password form is complete enough to be submitted.
    var canSubmit: Bool {
        !isLoading && credentials.isValid
    }

    /// Resolves the homeserver and picks the flow. Called when the user leaves the address field.
    func discover() async {
        await repository.discover(homeserver: homeserverText)

        updateFailure()
    }

    /// Submits the password form.
    func loginTapped() async {
        guard canSubmit else {
            return
        }

        await repository.signInWithPassword(
            homeserver : homeserverText,
            credentials: credentials
        )

        updateFailure()
    }

    /// Opens the OAuth sheet and signs in with whatever comes back.
    func oauthTapped() async {
        guard !isLoading else {
            return
        }

        await repository.signInWithOAuth(homeserver: homeserverText)

        updateFailure()
    }

    /// Drops the pending login when the user leaves the screen, so no client is left half built.
    func cancel() async {
        await repository.cancel()

        username = ""
        password = ""
        failure  = nil
    }

    private var credentials: PasswordCredentials {
        PasswordCredentials(
            username: username,
            password: password
        )
    }

    private func updateFailure() {
        guard let failure = repository.failure else {
            self.failure = nil

            return
        }

        self.failure = UserFacingFailure(
            title      : Self.title(for: failure),
            message    : failure.message,
            isRetryable: failure.isRetryable
        )
    }

    private static func title(for failure: AuthenticationFailure) -> String {
        switch failure {
            case .homeserverNotReachable: "Could not reach that homeserver"
            case .unsupportedLoginFlow  : "Swix cannot sign in here"
            case .invalidCredentials    : "Sign in failed"
            case .oauthCancelledByUser  : "Sign in cancelled"
            case .oauthCallbackMalformed: "Sign in could not be completed"
            case .sdk                   : "Something went wrong"
        }
    }
}
