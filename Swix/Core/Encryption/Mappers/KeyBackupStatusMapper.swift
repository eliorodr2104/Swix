//
//  KeyBackupStatusMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK

/// Turns the SDK's key backup states into the Core domain equivalents.
enum KeyBackupStatusMapper {

    /// Maps `BackupState`, the steady state of the server side room key backup.
    static func makeStatus(from state: BackupState) -> KeyBackupStatus {
        switch state {
            case .unknown    : .unknown
            case .creating   : .creating
            case .enabling   : .enabling
            case .resuming   : .resuming
            case .enabled    : .enabled
            case .downloading: .downloading
            case .disabling  : .disabling
        }
    }

    /// Maps `BackupUploadState`, which the SDK emits while it drains the pending room keys.
    ///
    /// The upload is reported as recovery progress rather than as its own model: from the user's
    /// point of view "waiting for the backup" is the same wait whichever call started it.
    static func makeProgress(from state: BackupUploadState) -> RecoveryProgress {
        switch state {
            case .waiting: .starting
                
            case .uploading(let backedUpCount, let totalCount):
                    .backingUp(
                        uploaded: Int(backedUpCount),
                        total   : Int(totalCount)
                    )
                
            case .error: .roomKeyUploadFailed
            case .done : .done
        }
    }
}
