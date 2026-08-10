//
//  PresenceState.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Domain mirror of the SDK's own presence enum.
///
/// The name is kept identical to the SDK's on purpose, since the two never collide outside the
/// Mappers and Services files that import MatrixRustSDK, where the SDK one is always reached
/// through its full `MatrixRustSDK.PresenceState` spelling.
enum PresenceState: Equatable {

    /// The user is actively using a client.
    case online

    /// The user has signed out or has no client connected.
    case offline

    /// The user has a client connected but has been idle for a while.
    case unavailable
}
