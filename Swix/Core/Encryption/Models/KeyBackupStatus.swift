//
//  KeyBackupStatus.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// Where the server side room key backup stands for this account.
///
/// `unknown` is ambiguous by design in the SDK: it means either no backup exists or one exists that
/// this device cannot reach, and only `backupExistsOnServer()` can tell the two apart.
enum KeyBackupStatus: Equatable {

    /// No backup, or a backup this device has no access to.
    case unknown

    /// A new backup version is being created on the homeserver.
    case creating

    /// An existing backup is being turned on for this device.
    case enabling

    /// A backup this device already knew about is being picked back up after a restart.
    case resuming

    /// Room keys are being uploaded as they arrive.
    case enabled

    /// Keys are being pulled down from the backup, usually right after a verification.
    case downloading

    /// The backup is being removed from the homeserver.
    case disabling
}
