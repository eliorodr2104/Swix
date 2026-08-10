//
//  AuthenticationFailure.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation

/// Everything that can go wrong between typing a homeserver and owning a session.
///
/// `errorDescription` is deliberately left to `LocalizedError`'s default, exactly as in
/// `SessionFailure`: witnessing it would make the conformance cross main actor isolation.
enum AuthenticationFailure: SwixFailure {

    /// The homeserver could not be resolved or refused to answer the discovery request.
    case homeserverNotReachable(SDKErrorInfo)

    /// The homeserver only offers flows Swix does not implement, or no sliding sync to sync with.
    case unsupportedLoginFlow

    /// The username or the password was rejected.
    case invalidCredentials

    /// The user closed the OAuth sheet before authorizing Swix.
    case oauthCancelledByUser

    /// The OAuth provider redirected back with something that is not a usable callback.
    case oauthCallbackMalformed

    /// Any other SDK failure, already normalized.
    case sdk(SDKErrorInfo)

    /// Readable summary of the failure, safe to show once a view model has titled it.
    var message: String {
        switch self {
            
            case .unsupportedLoginFlow:
                "This homeserver does not offer a way to sign in that Swix supports."
            
            case .invalidCredentials:
                "Those credentials were rejected. Check the username and the password."
            
            case .oauthCancelledByUser:
                "The sign in was cancelled."
            
            case .oauthCallbackMalformed:
                "The homeserver sent back an authorization response Swix could not read."
            
            case .sdk(let info), .homeserverNotReachable(let info):
                info.message
        }
    }

    /// The normalized SDK error, absent for the failures that never reach the network.
    var sdkInfo: SDKErrorInfo? {
        switch self {
            case .unsupportedLoginFlow, .invalidCredentials, .oauthCancelledByUser, .oauthCallbackMalformed:
                nil
            
            case .homeserverNotReachable(let info), .sdk(let info):
                info
        }
    }

    /// Whether offering the user a retry makes sense for this failure.
    var isRetryable: Bool {
        switch self {
            case .unsupportedLoginFlow, .oauthCallbackMalformed:
                false
            
            case .invalidCredentials, .oauthCancelledByUser:
                true
            
            case .homeserverNotReachable(let info), .sdk(let info):
                Self.isRetryable(info)
        }
    }

    /// Normalizes anything thrown along the login path into this feature's vocabulary.
    ///
    /// Failures raised by the session layer arrive already classified, so their `SDKErrorInfo` is
    /// unwrapped rather than reflected into an opaque `.unknown`.
    static func wrapping(_ error: any Error) -> AuthenticationFailure {
        if let failure = error as? AuthenticationFailure {
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
