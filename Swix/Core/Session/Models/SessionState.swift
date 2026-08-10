//
//  SessionState.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Where the app stands with respect to being signed in, from launch to sign out.
enum SessionState: Equatable {

    /// Nothing has been attempted yet, the very first state after launch.
    case none

    /// A stored session was found and is being handed back to the SDK.
    case restoring

    /// There is a live, usable client for this account.
    case authenticated(UserSession)

    /// The homeserver rejected the token but the account keeps its local data.
    ///
    /// Signing back in reuses the same device and the same encrypted stores, so the message
    /// history and the verified device status survive.
    case softLoggedOut(UserSession)

    /// No account is signed in and nothing is stored for one.
    case loggedOut

    /// The account behind this state, both while signed in and while softly logged out.
    var userSession: UserSession? {
        switch self {
            case .authenticated(let session), .softLoggedOut(let session): session
            case .none, .restoring, .loggedOut: nil
        }
    }

    /// Whether there is a live client ready to serve every other feature.
    var isAuthenticated: Bool {
        switch self {
            case .authenticated: true
            case .none, .restoring, .softLoggedOut, .loggedOut: false
        }
    }

    /// Whether a stored session is being restored right now.
    var isRestoring: Bool {
        switch self {
            case .restoring: true
            case .none, .authenticated, .softLoggedOut, .loggedOut: false
        }
    }
}
