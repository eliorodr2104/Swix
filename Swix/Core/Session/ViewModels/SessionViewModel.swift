//
//  SessionViewModel.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation


/// What a view needs to know about the session: whether to show the app, the splash or the login,
/// and what went wrong when something did.
@Observable
final class SessionViewModel {

    /// The failure to present, if any. Views clear it by setting it back to nil.
    var failure: UserFacingFailure?

    @ObservationIgnored
    private let repository: SessionRepository

    init(repository: SessionRepository) {
        self.repository = repository
    }

    /// Whether there is a live account and the rest of the app can be shown.
    var isAuthenticated: Bool {
        repository.state.isAuthenticated
    }

    /// Whether a stored session is being brought back, which is the splash screen condition.
    var isRestoring: Bool {
        repository.state.isRestoring
    }

    /// The signed in account, also available while softly logged out.
    var userSession: UserSession? {
        repository.state.userSession
    }

    /// Whether the token expired but the local data is still there, so signing back in is cheap.
    var isSoftLoggedOut: Bool {
        if case .softLoggedOut = repository.state {
            return true
        }

        return false
    }

    /// Whether the homeserver took the session away rather than the user leaving on their own.
    ///
    /// Bind it to the "session expired" alert: setting it back to false is how the alert
    /// dismisses, so it plugs straight into `alert(isPresented:)`.
    var sessionWasRevoked: Bool {
        get { repository.sessionWasRevoked }
        set {
            guard !newValue else {
                return
            }

            repository.acknowledgeSessionRevocation()
        }
    }

    /// Restores the stored session at launch.
    func restore() async {
        await repository.restoreIfPossible()

        updateFailure()
    }

    /// Signs the current account out and erases its local data.
    func signOut() async {
        await repository.signOut()

        updateFailure()
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

    private static func title(for failure: SessionFailure) -> String {
        switch failure {
            case .restoreFailed      : "Could not restore your session"
            case .keychainUnavailable: "Could not reach the keychain"
            case .logoutFailed       : "Could not sign out cleanly"
            case .noActiveClient     : "No account is signed in"
            case .sdk                : "Something went wrong"
        }
    }
}
