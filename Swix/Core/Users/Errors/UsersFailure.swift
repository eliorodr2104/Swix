//
//  UsersFailure.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Everything that can go wrong while reading or changing profiles, presence or the ignore list.
///
/// `errorDescription` is deliberately left to `LocalizedError`'s default, same reasoning as
/// `SessionFailure`: witnessing it would make the conformance cross main actor isolation, so the
/// readable text lives in `message` instead.
enum UsersFailure: SwixFailure {

    /// The operation needs a signed in client, but the session has none right now.
    case noActiveClient

    /// Any other SDK failure, already normalized.
    case sdk(SDKErrorInfo)

    /// Readable summary of the failure, safe to show once a view model has titled it.
    var message: String {
        switch self {
            case .noActiveClient: "There is no signed in account to do this."
            case .sdk(let info): info.message
        }
    }

    /// The normalized SDK error, absent for the failure that never reaches the SDK.
    var sdkInfo: SDKErrorInfo? {
        switch self {
            case .noActiveClient: nil
            case .sdk(let info): info
        }
    }

    /// Whether offering the user a retry makes sense for this failure.
    var isRetryable: Bool {
        switch self {
            case .noActiveClient: false
            case .sdk(let info): Self.isRetryable(info)
        }
    }

    /// Normalizes anything thrown along the way into this feature's vocabulary, unwrapping an
    /// already classified failure instead of reflecting it into an opaque `.unknown`.
    static func wrapping(_ error: any Error) -> UsersFailure {
        if let failure = error as? UsersFailure {
            return failure
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
