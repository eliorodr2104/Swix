//
//  TimelineFailure.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Everything that can go wrong while showing a room's timeline or acting on one of its events.
///
/// `errorDescription` is deliberately left to `LocalizedError`'s default, same reasoning as
/// `SessionFailure` and `RoomListFailure`: witnessing it would make the conformance cross main actor
/// isolation, so the readable text lives in `message` instead.
enum TimelineFailure: SwixFailure {

    /// A timeline was opened before sync produced a room list to look the room up in.
    case notStarted

    /// The room exists as an id but the room list cannot hand it over, most often right after the
    /// user left it.
    case roomUnavailable(SDKErrorInfo)

    /// The room was found but its timeline could not be built or refused to attach a listener.
    case timelineUnavailable(SDKErrorInfo)

    /// A message reached the send queue and the queue rejected it.
    case sendFailed(SDKErrorInfo)

    /// Asking the homeserver for older events failed.
    case paginationFailed(SDKErrorInfo)

    /// An edit, a redaction, a reaction, a vote or a receipt came back rejected.
    case actionFailed(SDKErrorInfo)

    /// An operation that needs the client itself ran with no signed in account.
    case noActiveClient

    /// Readable summary of the failure, safe to show once a view model has titled it.
    var message: String {
        switch self {
            case .notStarted: "This conversation is not ready yet."
            case .roomUnavailable: "That conversation is no longer available."
            case .timelineUnavailable(let info): info.message
            case .sendFailed(let info): info.message
            case .paginationFailed(let info): info.message
            case .actionFailed(let info): info.message
            case .noActiveClient: "There is no signed in account."
        }
    }

    /// The normalized SDK error, absent for the failures that never reach the SDK.
    var sdkInfo: SDKErrorInfo? {
        switch self {
            case .notStarted, .noActiveClient: nil
            case .roomUnavailable(let info): info
            case .timelineUnavailable(let info): info
            case .sendFailed(let info): info
            case .paginationFailed(let info): info
            case .actionFailed(let info): info
        }
    }

    /// Whether offering the user a retry makes sense for this failure.
    var isRetryable: Bool {
        switch self {
            case .notStarted, .noActiveClient, .roomUnavailable: false
            case .timelineUnavailable(let info): Self.isRetryable(info)
            case .sendFailed(let info): Self.isRetryable(info)
            case .paginationFailed(let info): Self.isRetryable(info)
            case .actionFailed(let info): Self.isRetryable(info)
        }
    }

    /// Normalizes anything thrown underneath the timeline, so callers that only ever see
    /// `any Error` still produce a typed failure instead of a bare unknown.
    static func wrapping(_ error: any Error) -> TimelineFailure {
        if let failure = error as? TimelineFailure {
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
