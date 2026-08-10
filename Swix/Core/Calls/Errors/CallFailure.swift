//
//  CallFailure.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation

/// Everything that can go wrong while preparing an Element Call session or requesting an OpenID
/// token for it.
///
/// `errorDescription` is deliberately left to `LocalizedError`'s default, same reasoning as every
/// other `SwixFailure`: witnessing it would make the conformance cross main actor isolation, so the
/// readable text lives in `message` instead.
enum CallFailure: SwixFailure {

    /// A call was requested before a session produced a live client.
    case noActiveClient

    /// The room this call belongs to could not be found through the room list.
    case roomUnavailable(SDKErrorInfo)

    /// Building the widget settings, the webview URL or the widget driver failed.
    case widgetSetupFailed(SDKErrorInfo)

    /// The homeserver refused to issue an OpenID token for the SFU handshake.
    case openIdTokenFailed(SDKErrorInfo)

    /// Any other SDK failure, already normalized.
    case sdk(SDKErrorInfo)

    /// Readable summary of the failure, safe to show once a view model has titled it.
    var message: String {
        switch self {
            case .noActiveClient             : "There is no signed in account to start a call with."
            case .roomUnavailable(let info)  : info.message
            case .widgetSetupFailed(let info): info.message
            case .openIdTokenFailed(let info): info.message
            case .sdk(let info)              : info.message
        }
    }

    /// The normalized SDK error, absent for the one failure that never reaches the SDK.
    var sdkInfo: SDKErrorInfo? {
        switch self {
            case .noActiveClient: nil
            case .roomUnavailable(let info),  .widgetSetupFailed(let info), .openIdTokenFailed(let info), .sdk(let info): info
        }
    }

    /// Whether offering the user a retry makes sense for this failure.
    var isRetryable: Bool {
        switch self {
            case .noActiveClient: false
            case .roomUnavailable(let info),  .widgetSetupFailed(let info), .openIdTokenFailed(let info), .sdk(let info): Self.isRetryable(info)
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
