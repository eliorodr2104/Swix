//
//  ThreadsFailure.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Everything that can go wrong while listing a room's threads, opening one, or following it.
///
/// `errorDescription` is deliberately left to `LocalizedError`'s default, same reasoning as
/// `TimelineFailure` and `RoomListFailure`: witnessing it would make the conformance cross main
/// actor isolation, so the readable text lives in `message` instead.
enum ThreadsFailure: SwixFailure {

    /// A thread list was asked for before sync produced a room list to look the room up in, or a
    /// page was asked for before the list was attached.
    case notStarted

    /// The room exists as an id but the room list cannot hand it over, most often right after the
    /// user left it.
    case roomUnavailable(SDKErrorInfo)

    /// The room was found but its thread list could not be built or refused a listener.
    case listUnavailable(SDKErrorInfo)

    /// Asking the homeserver for another page of threads failed.
    case paginationFailed(SDKErrorInfo)

    /// The conversation of one thread could not be opened.
    case threadUnavailable(SDKErrorInfo)

    /// Reading or writing whether the account follows a thread failed.
    case subscriptionFailed(SDKErrorInfo)

    /// Readable summary of the failure, safe to show once a view model has titled it.
    var message: String {
        switch self {
            case .notStarted: "This room's threads are not ready yet."
            case .roomUnavailable: "That conversation is no longer available."
            case .listUnavailable(let info): info.message
            case .paginationFailed(let info): info.message
            case .threadUnavailable(let info): info.message
            case .subscriptionFailed(let info): info.message
        }
    }

    /// The normalized SDK error, absent for the one failure that never reaches the SDK.
    var sdkInfo: SDKErrorInfo? {
        switch self {
            case .notStarted: nil
            case .roomUnavailable(let info): info
            case .listUnavailable(let info): info
            case .paginationFailed(let info): info
            case .threadUnavailable(let info): info
            case .subscriptionFailed(let info): info
        }
    }

    /// Whether offering the user a retry makes sense for this failure.
    var isRetryable: Bool {
        switch self {
            case .notStarted, .roomUnavailable: false
            case .listUnavailable(let info): Self.isRetryable(info)
            case .paginationFailed(let info): Self.isRetryable(info)
            case .threadUnavailable(let info): Self.isRetryable(info)
            case .subscriptionFailed(let info): Self.isRetryable(info)
        }
    }

    /// Normalizes anything thrown underneath a thread screen, so callers that only ever see
    /// `any Error` still produce a typed failure instead of a bare unknown.
    ///
    /// A thread's conversation is an ordinary timeline, so opening one fails with the Timeline
    /// feature's own error. That one is translated here rather than let through, because a thread
    /// screen has no business presenting another feature's vocabulary.
    static func wrapping(_ error: any Error) -> ThreadsFailure {
        if let failure = error as? ThreadsFailure {
            return failure
        }

        if let timelineFailure = error as? TimelineFailure {
            return .threadUnavailable(Self.info(from: timelineFailure))
        }

        return .listUnavailable(SDKErrorInfo(error))
    }

    /// A `TimelineFailure` that never reached the SDK has no error to carry, and its own readable
    /// text is the best thing left to keep.
    private static func info(from failure: TimelineFailure) -> SDKErrorInfo {
        guard let info = failure.sdkInfo else {
            return SDKErrorInfo(
                kind   : .unknown,
                message: failure.message,
                details: nil
            )
        }

        return info
    }

    /// Only failures that a later attempt can plausibly survive are worth a retry button.
    private static func isRetryable(_ info: SDKErrorInfo) -> Bool {
        switch info.kind {
            case .network, .rateLimited: true
            case .authenticationExpired, .forbidden, .notFound, .unknown: false
        }
    }
}
