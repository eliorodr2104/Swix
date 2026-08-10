//
//  MediaFailure.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Everything that can go wrong while uploading, downloading or scanning media.
///
/// `errorDescription` is deliberately left to `LocalizedError`'s default, same reasoning as
/// `SessionFailure`: witnessing it would make the conformance cross main actor isolation, so the
/// readable text lives in `message` instead.
enum MediaFailure: SwixFailure {

    /// The stored media source could not be parsed back into something the SDK accepts.
    case invalidSource(reason: String)

    /// The homeserver refused or dropped the upload.
    case uploadFailed(SDKErrorInfo)

    /// The file is bigger than the homeserver's declared limit, so uploading it would only waste
    /// the user's bandwidth before being rejected.
    case uploadTooLarge(byteCount: Int, maximumByteCount: Int)

    /// The media could not be fetched or decrypted.
    case downloadFailed(SDKErrorInfo)

    /// The media was fetched but the file backing it could not be handed to the caller.
    case fileUnavailable(reason: String)

    /// The content scanner rejected the file or could not reach the scanning server.
    case scanFailed(SDKErrorInfo)

    /// Media work was requested before a session produced a live client.
    case noActiveClient

    /// Any other SDK failure, already normalized.
    case sdk(SDKErrorInfo)

    /// Readable summary of the failure, safe to show once a view model has titled it.
    var message: String {
        switch self {
            case .invalidSource(let reason): "This attachment cannot be opened. \(reason)"
            case .uploadFailed(let info): info.message
            case .uploadTooLarge(let byteCount, let maximumByteCount): Self.tooLargeMessage(byteCount: byteCount, maximumByteCount: maximumByteCount)
            case .downloadFailed(let info): info.message
            case .fileUnavailable(let reason): "The downloaded file is no longer available. \(reason)"
            case .scanFailed(let info): info.message
            case .noActiveClient: "There is no signed in account to transfer media with."
            case .sdk(let info): info.message
        }
    }

    /// The normalized SDK error, absent for the failures that never reach the SDK.
    var sdkInfo: SDKErrorInfo? {
        switch self {
            case .uploadFailed(let info), .downloadFailed(let info), .scanFailed(let info), .sdk(let info): info
            case .invalidSource, .uploadTooLarge, .fileUnavailable, .noActiveClient: nil
        }
    }

    /// Whether offering the user a retry makes sense for this failure.
    var isRetryable: Bool {
        switch self {
            case .uploadFailed(let info), .downloadFailed(let info), .scanFailed(let info), .sdk(let info): Self.isRetryable(info)
            case .invalidSource, .uploadTooLarge, .fileUnavailable, .noActiveClient: false
        }
    }

    /// Only failures that a later attempt can plausibly survive are worth a retry button.
    private static func isRetryable(_ info: SDKErrorInfo) -> Bool {
        switch info.kind {
            case .network, .rateLimited: true
            case .authenticationExpired, .forbidden, .notFound, .unknown: false
        }
    }

    /// Spells out both sizes with `ByteCountFormatter` so the user reads the same units the rest
    /// of the system uses.
    private static func tooLargeMessage(
        byteCount       : Int,
        maximumByteCount: Int
    ) -> String {

        let formatter = ByteCountFormatter()
        let size = formatter.string(fromByteCount: Int64(byteCount))
        let limit = formatter.string(fromByteCount: Int64(maximumByteCount))

        return "This file is \(size), but the server accepts at most \(limit)."
    }
}
