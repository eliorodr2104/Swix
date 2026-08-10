//
//  LocationFailure.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Everything that can go wrong sending a location or running a live share.
///
/// `errorDescription` is deliberately left to `LocalizedError`'s default, same reasoning as
/// `TimelineFailure` and `MediaFailure`: witnessing it would make the conformance cross main actor
/// isolation, so the readable text lives in `message` instead.
enum LocationFailure: SwixFailure {

    /// A room's live shares were asked for before sync produced a room list to look it up in.
    case notStarted

    /// The room exists as an id but the room list cannot hand it over, most often right after the
    /// user left it.
    case roomUnavailable(SDKErrorInfo)

    /// A one-shot location message reached the send queue and the queue rejected it.
    case sendFailed(SDKErrorInfo)

    /// Starting or stopping a live share was refused by the homeserver.
    case shareFailed(SDKErrorInfo)

    /// Any other rejected operation, already normalized.
    case actionFailed(SDKErrorInfo)

    /// An operation that needs the client itself ran with no signed in account.
    case noActiveClient

    /// Readable summary of the failure, safe to show once a view model has titled it.
    var message: String {
        switch self {
            case .notStarted: "Location sharing is not ready yet."
            case .roomUnavailable: "That conversation is no longer available."
            case .sendFailed(let info): info.message
            case .shareFailed(let info): info.message
            case .actionFailed(let info): info.message
            case .noActiveClient: "There is no signed in account."
        }
    }

    /// The normalized SDK error, absent for the failures that never reach the SDK.
    var sdkInfo: SDKErrorInfo? {
        switch self {
            case .notStarted, .noActiveClient: nil
            case .roomUnavailable(let info): info
            case .sendFailed(let info): info
            case .shareFailed(let info): info
            case .actionFailed(let info): info
        }
    }

    /// Whether offering the user a retry makes sense for this failure.
    var isRetryable: Bool {
        switch self {
            case .notStarted, .noActiveClient, .roomUnavailable: false
            case .sendFailed(let info): Self.isRetryable(info)
            case .shareFailed(let info): Self.isRetryable(info)
            case .actionFailed(let info): Self.isRetryable(info)
        }
    }

    /// Normalizes anything thrown underneath a location operation, so callers that only ever see
    /// `any Error` still produce a typed failure instead of a bare unknown.
    static func wrapping(_ error: any Error) -> LocationFailure {
        if let failure = error as? LocationFailure {
            return failure
        }

        return .actionFailed(SDKErrorInfo(error))
    }

    /// Only failures that a later attempt can plausibly survive are worth a retry button.
    private static func isRetryable(_ info: SDKErrorInfo) -> Bool {
        switch info.kind {
            case .network, .rateLimited: true
            case .authenticationExpired, .forbidden, .notFound, .unknown: false
        }
    }
}
