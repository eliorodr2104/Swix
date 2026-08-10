//
//  SearchFailure.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Everything that can go wrong across the three searches: local messages, the public room
/// directory and the user directory.
///
/// `errorDescription` is deliberately left to `LocalizedError`'s default: witnessing it would make
/// the conformance cross main actor isolation, so the readable text lives in `message` instead.
enum SearchFailure: SwixFailure {

    /// A search was asked for while no account is signed in.
    case noActiveClient

    /// The local index refused the query, most often because it was never built.
    case queryFailed(SDKErrorInfo)

    /// Loading one more page of results failed.
    case paginationFailed(SDKErrorInfo)

    /// The homeserver refused the public room directory request.
    case directoryFailed(SDKErrorInfo)

    /// The homeserver refused the user directory request.
    case userSearchFailed(SDKErrorInfo)

    /// Readable summary of the failure, safe to show once a view model has titled it.
    var message: String {
        switch self {
            case .noActiveClient: "There is no signed in account."
            case .queryFailed(let info), .paginationFailed(let info): info.message
            case .directoryFailed(let info), .userSearchFailed(let info): info.message
        }
    }

    /// The normalized SDK error, absent for the failures that never reach the SDK.
    var sdkInfo: SDKErrorInfo? {
        switch self {
            case .noActiveClient: nil
            case .queryFailed(let info), .paginationFailed(let info): info
            case .directoryFailed(let info), .userSearchFailed(let info): info
        }
    }

    /// Whether offering the user a retry makes sense for this failure.
    var isRetryable: Bool {
        switch self {
            case .noActiveClient: false
            case .queryFailed(let info), .paginationFailed(let info): Self.isRetryable(info)
            case .directoryFailed(let info), .userSearchFailed(let info): Self.isRetryable(info)
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
