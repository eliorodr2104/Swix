//
//  RoomListFailure.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Everything that can go wrong while building the chat list or acting on one of its rooms.
///
/// `errorDescription` is deliberately left to `LocalizedError`'s default, same reasoning as
/// `SessionFailure` and `SyncFailure`: witnessing it would make the conformance cross main actor
/// isolation, so the readable text lives in `message` instead.
enum RoomListFailure: SwixFailure {

    /// The chat list was asked for rooms before sync produced a room list service.
    case notStarted

    /// The room list itself could not be built or refused to hand over its entries.
    case listUnavailable(SDKErrorInfo)

    /// A room the user acted on is not in the list, most often because it was just left.
    case roomUnavailable(SDKErrorInfo)

    /// A room action reached the server and came back rejected.
    case actionFailed(SDKErrorInfo)

    /// An action that needs the client directly ran with no signed in account.
    case noActiveClient

    /// Readable summary of the failure, safe to show once a view model has titled it.
    var message: String {
        switch self {
            case .notStarted: "The chat list is not ready yet."
            case .listUnavailable(let info): info.message
            case .roomUnavailable: "That chat is no longer available."
            case .actionFailed(let info): info.message
            case .noActiveClient: "There is no signed in account."
        }
    }

    /// The normalized SDK error, absent for the failures that never reach the SDK.
    var sdkInfo: SDKErrorInfo? {
        switch self {
            case .notStarted, .noActiveClient: nil
            case .listUnavailable(let info): info
            case .roomUnavailable(let info): info
            case .actionFailed(let info): info
        }
    }

    /// Whether offering the user a retry makes sense for this failure.
    var isRetryable: Bool {
        switch self {
            case .notStarted, .noActiveClient, .roomUnavailable: false
            case .listUnavailable(let info): Self.isRetryable(info)
            case .actionFailed(let info): Self.isRetryable(info)
        }
    }

    /// Normalizes anything thrown underneath the room list, so callers that only ever see
    /// `any Error` still produce a typed failure instead of a bare unknown.
    static func wrapping(_ error: any Error) -> RoomListFailure {
        if let failure = error as? RoomListFailure {
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
