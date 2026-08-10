//
//  RoomSettingsFailure.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Everything that can go wrong while reading or editing one room's settings.
///
/// `errorDescription` is deliberately left to `LocalizedError`'s default, same reasoning as
/// `RoomListFailure`: witnessing it would make the conformance cross main actor isolation, so the
/// readable text lives in `message` instead.
enum RoomSettingsFailure: SwixFailure {

    /// Room settings work was requested before a session produced a live client.
    case noActiveClient

    /// The room being read or edited is not one the account currently has access to.
    case roomUnavailable(SDKErrorInfo)

    /// The homeserver rejected or dropped a settings change.
    case updateFailed(SDKErrorInfo)

    /// The room's current settings could not be read back after a change, or on first load.
    case snapshotUnavailable(SDKErrorInfo)

    /// Readable summary of the failure, safe to show once a view model has titled it.
    var message: String {
        switch self {
            case .noActiveClient: "There is no signed in account."
            case .roomUnavailable(let info): info.message
            case .updateFailed(let info): info.message
            case .snapshotUnavailable(let info): info.message
        }
    }

    /// The normalized SDK error, absent for the failures that never reach the SDK.
    var sdkInfo: SDKErrorInfo? {
        switch self {
            case .noActiveClient: nil
            case .roomUnavailable(let info): info
            case .updateFailed(let info): info
            case .snapshotUnavailable(let info): info
        }
    }

    /// Whether offering the user a retry makes sense for this failure.
    var isRetryable: Bool {
        switch self {
            case .noActiveClient, .roomUnavailable: false
            case .updateFailed(let info), .snapshotUnavailable(let info): Self.isRetryable(info)
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
