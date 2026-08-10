//
//  SDKErrorKind.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// A coarse, SDK-agnostic bucket for any error the Matrix SDK can raise.
///
/// Feature errors classify into one of these instead of switching on raw SDK enums themselves,
/// which is what keeps `import MatrixRustSDK` confined to the layers allowed to use it.
enum SDKErrorKind {

    case network
    case authenticationExpired
    case forbidden
    case notFound
    case rateLimited
    case unknown
}
