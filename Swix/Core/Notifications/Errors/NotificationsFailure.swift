//
//  NotificationsFailure.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Everything that can go wrong while reading push settings, registering a pusher or resolving a
/// notification.
///
/// `errorDescription` is deliberately left to `LocalizedError`'s default, exactly as in
/// `SessionFailure`: witnessing it would make the conformance cross main actor isolation.
enum NotificationsFailure: SwixFailure {

    /// Push was asked about before a session produced a live client.
    case noActiveClient

    /// The account's push rules could not be read.
    case settingsUnavailable(SDKErrorInfo)

    /// A push rule was rejected by the homeserver.
    case updateFailed(SDKErrorInfo)

    /// The notification client could not be built, so notifications cannot be resolved at all.
    case notificationClientUnavailable(SDKErrorInfo)

    /// The homeserver refused to register or to delete the pusher.
    case pusherRegistrationFailed(SDKErrorInfo)

    /// Any other SDK failure, already normalized.
    case sdk(SDKErrorInfo)

    /// Readable summary of the failure, safe to show once a view model has titled it.
    var message: String {
        switch self {
            case .noActiveClient: "There is no signed in account to read notification settings for."
            case .settingsUnavailable(let info): info.message
            case .updateFailed(let info): info.message
            case .notificationClientUnavailable(let info): info.message
            case .pusherRegistrationFailed(let info): info.message
            case .sdk(let info): info.message
        }
    }

    /// The normalized SDK error, absent for the failures that never reach the SDK.
    var sdkInfo: SDKErrorInfo? {
        switch self {
            case .noActiveClient: nil
            case .settingsUnavailable(let info),
                 .updateFailed(let info),
                 .notificationClientUnavailable(let info),
                 .pusherRegistrationFailed(let info),
                 .sdk(let info): info
        }
    }

    /// Whether offering the user a retry makes sense for this failure.
    var isRetryable: Bool {
        switch self {
            case .noActiveClient: false
            case .settingsUnavailable(let info),
                 .updateFailed(let info),
                 .notificationClientUnavailable(let info),
                 .pusherRegistrationFailed(let info),
                 .sdk(let info): Self.isRetryable(info)
        }
    }

    /// Normalizes anything thrown along the notification paths into this feature's vocabulary.
    ///
    /// Failures raised by the session layer arrive already classified, so their `SDKErrorInfo` is
    /// unwrapped rather than reflected into an opaque `.unknown`.
    static func wrapping(_ error: any Error) -> NotificationsFailure {
        if let failure = error as? NotificationsFailure {
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
