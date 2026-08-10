//
//  RecoveryStatusMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK

/// Turns everything the SDK reports about recovery into the Core domain equivalents.
enum RecoveryStatusMapper {

    /// Maps `RecoveryState`, the steady state of secret storage for this account.
    static func makeStatus(from state: RecoveryState) -> RecoveryStatus {
        switch state {
            case .unknown   : .unknown
            case .enabled   : .enabled
            case .disabled  : .disabled
            case .incomplete: .incomplete
        }
    }

    /// Maps `EnableRecoveryProgress`, the running commentary of one `enableRecovery` call.
    ///
    /// The recovery key carried by the SDK's `done` case is dropped here on purpose: the same key
    /// is the return value of the call, and a secret that appears in two places tends to get logged
    /// in one of them.
    static func makeProgress(from progress: EnableRecoveryProgress) -> RecoveryProgress {
        
        switch progress {
            case .starting           : .starting
            case .creatingBackup     : .creatingBackup
            case .creatingRecoveryKey: .creatingRecoveryKey
            
            case .backingUp(let backedUpCount, let totalCount):
                    .backingUp(
                        uploaded: Int(backedUpCount),
                        total   : Int(totalCount)
                    )
            
            case .roomKeyUploadError: .roomKeyUploadFailed
            case .done              : .done
        }
    }
}
