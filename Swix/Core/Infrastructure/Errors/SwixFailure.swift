//
//  SwixFailure.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Contract every feature-level error enum (`SessionFailure`, `TimelineFailure`, ...) conforms to.
///
/// The "Failure" suffix on those enums is deliberate: it avoids colliding with the SDK's own
/// error enums (`ClientError`, `RoomError`, ...) while still reading naturally at call sites.
protocol SwixFailure: LocalizedError {

    /// The normalized SDK error this failure was built from, if it originated from one.
    var sdkInfo: SDKErrorInfo? { get }

    /// Whether retrying the same operation has a realistic chance of succeeding.
    var isRetryable: Bool { get }
}
