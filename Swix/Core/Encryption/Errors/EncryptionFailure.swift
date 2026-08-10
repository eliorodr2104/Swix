//
//  EncryptionFailure.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation

/// Everything that can go wrong while verifying a device or managing recovery and key backup.
///
/// `errorDescription` is deliberately left to `LocalizedError`'s default, exactly as in
/// `SessionFailure`: witnessing it would make the conformance cross main actor isolation.
enum EncryptionFailure: SwixFailure {

    /// Encryption was asked for before a session produced a live client.
    case noActiveClient

    /// The verification controller could not be obtained from the homeserver.
    case verificationUnavailable(SDKErrorInfo)

    /// The recovery key the user typed does not open this account's secret storage.
    case invalidRecoveryKey(SDKErrorInfo)

    /// Enabling, resetting or disabling recovery failed.
    case recoveryFailed(SDKErrorInfo)

    /// The key backup could not be read or written.
    case backupFailed(SDKErrorInfo)

    /// The other device negotiated a comparison method Swix cannot present.
    case unsupportedVerificationMethod

    /// Any other SDK failure, already normalized.
    case sdk(SDKErrorInfo)

    /// Readable summary of the failure, safe to show once a view model has titled it.
    var message: String {
        switch self {
            case .noActiveClient: 
                "There is no signed in account to set up encryption for."
            
            case .invalidRecoveryKey:
                "That recovery key does not unlock this account. Check it and try again."
            
            case .unsupportedVerificationMethod:
                "The other device asked to compare numbers, which Swix cannot show."
            
            case .sdk(let info), .verificationUnavailable(let info),
                 .recoveryFailed(let info), .backupFailed(let info):
                info.message
        }
    }

    /// The normalized SDK error, absent for the failures that never reach the SDK.
    var sdkInfo: SDKErrorInfo? {
        switch self {
            case .noActiveClient, .unsupportedVerificationMethod: nil
            case .verificationUnavailable(let info),
                 .invalidRecoveryKey(let info),
                 .recoveryFailed(let info),
                 .backupFailed(let info),
                 .sdk(let info): info
        }
    }

    /// Whether offering the user a retry makes sense for this failure.
    var isRetryable: Bool {
        switch self {
            case .noActiveClient, .unsupportedVerificationMethod: false
            case .invalidRecoveryKey: true
            case .verificationUnavailable(let info),
                 .recoveryFailed(let info),
                 .backupFailed(let info),
                 .sdk(let info): Self.isRetryable(info)
        }
    }

    /// Normalizes anything thrown along an encryption path into this feature's vocabulary.
    ///
    /// Failures raised by a neighbouring layer arrive already classified, so their `SDKErrorInfo` is
    /// unwrapped rather than reflected into an opaque `.unknown`.
    static func wrapping(_ error: any Error) -> EncryptionFailure {
        if let failure = error as? EncryptionFailure {
            return failure
        }

        if let info = (error as? any SwixFailure)?.sdkInfo {
            return .sdk(info)
        }

        return .sdk(SDKErrorInfo(error))
    }

    /// Only failures that a later attempt can plausibly survive are worth a retry button.
    private static func isRetryable(_ info: SDKErrorInfo) -> Bool {
        switch info.kind {
            case .network, .rateLimited: true
            case .authenticationExpired, .forbidden, .notFound, .unknown: false
        }
    }
}
