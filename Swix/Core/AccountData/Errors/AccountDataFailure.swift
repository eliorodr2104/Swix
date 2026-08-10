//
//  AccountDataFailure.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Everything that can go wrong while reading, writing or observing account data, global or room
/// scoped.
///
/// `errorDescription` is deliberately left to `LocalizedError`'s default, same reasoning as
/// `RoomListFailure`: witnessing it would make the conformance cross main actor isolation, so the
/// readable text lives in `message` instead.
enum AccountDataFailure: SwixFailure {

    /// Account data work was requested before a session produced a live client.
    case noActiveClient

    /// The homeserver could not be asked for the current value.
    case fetchFailed(SDKErrorInfo)

    /// The homeserver rejected or dropped the new value.
    case saveFailed(SDKErrorInfo)

    /// `content` could not be turned into JSON, most often because its declared `Encodable`
    /// conformance does not actually cover every value it can hold.
    case encodingFailed(eventType: String)

    /// The stored or received JSON does not match the shape the caller asked to decode.
    case decodingFailed(eventType: String)

    /// `eventType` has no matching case in the SDK's own closed account data enum, so it cannot
    /// be observed even though it can still be fetched or set directly.
    case unobservable(eventType: String)

    /// The room being observed is not one the account currently has access to.
    case roomUnavailable(SDKErrorInfo)

    /// Readable summary of the failure, safe to show once a view model has titled it.
    var message: String {
        switch self {
            case .noActiveClient: "There is no signed in account."
            case .fetchFailed(let info): info.message
            case .saveFailed(let info): info.message
            case .encodingFailed(let eventType): "\"\(eventType)\" could not be saved in that shape."
            case .decodingFailed(let eventType): "\"\(eventType)\" is not stored in the shape that was expected."
            case .unobservable(let eventType): "\"\(eventType)\" cannot be watched for changes."
            case .roomUnavailable(let info): info.message
        }
    }

    /// The normalized SDK error, absent for the failures that never reach the SDK.
    var sdkInfo: SDKErrorInfo? {
        switch self {
            case .noActiveClient, .encodingFailed, .decodingFailed, .unobservable: nil
            case .fetchFailed(let info), .saveFailed(let info), .roomUnavailable(let info): info
        }
    }

    /// Whether offering the user a retry makes sense for this failure.
    var isRetryable: Bool {
        switch self {
            case .noActiveClient, .encodingFailed, .decodingFailed, .unobservable, .roomUnavailable: false
            case .fetchFailed(let info), .saveFailed(let info): Self.isRetryable(info)
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
