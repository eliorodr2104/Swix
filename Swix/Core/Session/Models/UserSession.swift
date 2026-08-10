//
//  UserSession.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// The signed in account in the shape the app actually needs: who we are, on which device, and
/// against which homeserver.
struct UserSession: Equatable, Identifiable {

    /// The Matrix user identifier, for instance `@alice:matrix.org`.
    let userID: String

    /// The device this session logged in as, which E2EE and verification are bound to.
    let deviceID: String

    /// The homeserver every request of this session is sent to.
    let homeserverURL: String

    /// Whether the session was obtained through OAuth rather than a password login.
    let usedOAuth: Bool

    /// One live session per account, so the account identifies the session.
    var id: String { userID }

    init(
        userID       : String,
        deviceID     : String,
        homeserverURL: String,
        usedOAuth    : Bool
    ) {
        self.userID        = userID
        self.deviceID      = deviceID
        self.homeserverURL = homeserverURL
        self.usedOAuth     = usedOAuth
    }
}
