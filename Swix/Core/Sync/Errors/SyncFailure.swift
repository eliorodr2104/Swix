//
//  SyncFailure.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Everything that can go wrong while building or driving the sync engine.
///
/// `errorDescription` is deliberately left to `LocalizedError`'s default, same reasoning as
/// `SessionFailure`: witnessing it would make the conformance cross main actor isolation, so the
/// readable text lives in `message` instead.
enum SyncFailure: SwixFailure {

    /// The SDK sync service could not be built or refused to start.
    case startFailed(SDKErrorInfo)

    /// Sync was asked to run before a session produced a live client.
    case noActiveClient

    /// A room was requested through `RoomProviding` before sync ever started, so the room list
    /// service backing it does not exist yet.
    case notStarted

    /// Readable summary of the failure, safe to show once a view model has titled it.
    var message: String {
        switch self {
            case .startFailed(let info): info.message
            case .noActiveClient: "There is no signed in account to sync."
            case .notStarted: "Sync has not started yet."
        }
    }

    /// The normalized SDK error, absent for the failures that never reach the SDK.
    var sdkInfo: SDKErrorInfo? {
        switch self {
            case .startFailed(let info): info
            case .noActiveClient, .notStarted: nil
        }
    }

    /// Whether offering the user a retry makes sense for this failure.
    var isRetryable: Bool {
        switch self {
            case .startFailed(let info): Self.isRetryable(info)
            case .noActiveClient, .notStarted: false
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
