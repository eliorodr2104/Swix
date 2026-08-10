//
//  SessionEvent.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Everything the SDK reports about the client as a whole, already translated out of the bridge.
///
/// The stream that carries these never fails: a transport error is an event like any other, so a
/// consumer that stops iterating would stop noticing that the session died.
enum SessionEvent: Equatable {

    /// The homeserver refused the access token. A soft logout keeps the local data usable.
    case authenticationExpired(isSoftLogout: Bool)

    /// A task the SDK runs on our behalf died. Informational, the session stays valid.
    case backgroundTaskFailed(taskName: String, reason: String)
}
