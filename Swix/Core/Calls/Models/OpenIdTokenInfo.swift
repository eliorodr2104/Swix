//
//  OpenIdTokenInfo.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// A short lived OpenID token the homeserver issued for this account, mirroring the SDK's
/// `OpenIdToken` without exposing it: the SFU/LiveKit side of a call uses this to prove which
/// Matrix account is joining without the caller ever needing to know how the SDK represents it.
struct OpenIdTokenInfo: Equatable {

    /// The bearer token to present to the SFU.
    let accessToken: String

    /// The token scheme, normally "Bearer".
    let tokenType: String

    /// The homeserver's own server name, so the SFU can verify the token against it.
    let matrixServerName: String

    /// How many seconds from issuance the token stays valid.
    let expiresInSeconds: UInt64
}
