//
//  PresenceStateMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Translates the domain `PresenceState` into the SDK's identically named enum.
///
/// Only this one direction exists because the SDK has no listener for presence changes, only the
/// `setPresence` setter this feature drives; a reverse mapping would have no caller.
enum PresenceStateMapper {

    /// Turns the domain presence enum into what `Client.setPresence` expects.
    static func makeSDKPresenceState(from presence: PresenceState) -> MatrixRustSDK.PresenceState {
        switch presence {
            case .online: .online
            case .offline: .offline
            case .unavailable: .unavailable
        }
    }
}
