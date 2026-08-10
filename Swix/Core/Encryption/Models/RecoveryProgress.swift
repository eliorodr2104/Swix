//
//  RecoveryProgress.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// How far along the one shot "turn recovery on" operation is.
///
/// Enabling recovery uploads every room key the device holds, which on a busy account is minutes of
/// work, so the operation reports progress instead of just blocking until it is done.
enum RecoveryProgress: Equatable {

    /// The operation was accepted and nothing has happened yet.
    case starting

    /// A new key backup version is being created on the homeserver.
    case creatingBackup

    /// The recovery key itself is being generated and stored in secret storage.
    case creatingRecoveryKey

    /// Room keys are being uploaded to the new backup.
    case backingUp(uploaded: Int, total: Int)

    /// One batch of room keys failed to upload. The operation keeps going.
    case roomKeyUploadFailed

    /// Recovery is on and the key has been handed back to the caller.
    case done

    /// The share of keys already uploaded, nil while no upload is in flight.
    var fractionCompleted: Double? {
        switch self {
            case .backingUp(let uploaded, let total):
                total > 0 ? Double(uploaded) / Double(total) : 0
                
            case .done: 1
            default   : nil
        }
    }
}
