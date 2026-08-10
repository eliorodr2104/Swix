//
//  RecoveryStatus.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// Whether the account has a recovery key that can restore the message history on a new device.
enum RecoveryStatus: Equatable {

    /// Not determined yet, typically before the first sync completed.
    case unknown

    /// Recovery is set up and this device holds the secrets it needs.
    case enabled

    /// The account has no recovery at all, so losing every device loses the history.
    case disabled

    /// Recovery exists on the server but this device is missing part of it, which is exactly the
    /// state a fresh unverified sign in lands in until the user types the recovery key.
    case incomplete
}
