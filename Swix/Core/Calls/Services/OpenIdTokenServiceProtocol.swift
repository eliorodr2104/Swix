//
//  OpenIdTokenServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Requests a short lived OpenID token the account can present to an SFU, mirroring the SDK's own
/// `Client.requestOpenidToken()` behind a domain type.
protocol OpenIdTokenServiceProtocol {

    /// Asks the homeserver for a fresh token. Each call issues a new one; nothing is cached here.
    func requestToken() async throws -> OpenIdTokenInfo
}
