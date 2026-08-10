//
//  SessionFailure.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Everything that can go wrong while establishing, restoring or ending a session.
///
/// `errorDescription` is deliberately left to `LocalizedError`'s default: witnessing it would make
/// the conformance cross main actor isolation, so the readable text lives in `message` instead.
enum SessionFailure: SwixFailure {

    /// A stored session exists but could not be handed back to the SDK.
    case restoreFailed(SDKErrorInfo)

    /// The keychain refused to give back or to store the credentials.
    case keychainUnavailable(reason: String)

    /// The homeserver rejected the logout. The local session is dropped anyway.
    case logoutFailed(SDKErrorInfo)

    /// An operation was asked of a session that has no live client behind it.
    case noActiveClient

    /// Any other SDK failure, already normalized.
    case sdk(SDKErrorInfo)

    /// Readable summary of the failure, safe to show once a view model has titled it.
    var message: String {
        switch self {
            case .keychainUnavailable(let reason): reason
            case .noActiveClient: "There is no signed in account."
            case .restoreFailed(let info), .logoutFailed(let info), .sdk(let info): info.message
        }
    }

    /// The normalized SDK error, absent for the failures that never reach the network.
    var sdkInfo: SDKErrorInfo? {
        switch self {
            case .keychainUnavailable, .noActiveClient: nil
            case .restoreFailed(let info), .logoutFailed(let info), .sdk(let info): info
        }
    }

    /// Whether offering the user a retry makes sense for this failure.
    var isRetryable: Bool {
        switch self {
            case .keychainUnavailable, .noActiveClient: false
            case .restoreFailed(let info), .logoutFailed(let info), .sdk(let info): Self.isRetryable(info)
        }
    }

    /// Only failures that a later attempt can plausibly survive are worth a retry button.
    private static func isRetryable(_ info: SDKErrorInfo) -> Bool {
        switch info.kind {
            case .network, .rateLimited: true
            case .authenticationExpired, .forbidden, .notFound, .unknown: false
        }
    }
}
