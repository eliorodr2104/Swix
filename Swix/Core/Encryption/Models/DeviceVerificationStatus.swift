//
//  DeviceVerificationStatus.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// Whether this device is trusted by the account's own cross signing identity.
///
/// This is the single fact that decides if the app can read the key backup and show old encrypted
/// history, so the whole verification feature exists to move it from `unverified` to `verified`.
enum DeviceVerificationStatus: Equatable {

    /// Nothing conclusive yet, either because the first sync has not finished or because the
    /// account has no cross signing identity to compare this device against.
    case unknown

    /// The device is signed by the account identity, so backups and history are readable.
    case verified

    /// The account has an identity but this device is not signed by it.
    case unverified
}
