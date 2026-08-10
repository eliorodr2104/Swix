//
//  OAuthConfigurationProvider.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// Builds the OAuth client metadata Swix advertises to every homeserver it authenticates against.
enum OAuthConfigurationProvider {

    /// `staticRegistrations` lets a homeserver skip dynamic client registration for clients it
    /// pre-registers (matrix.org does this for some clients); empty since Swix registers dynamically.
    static func makeMetadata() -> OAuthClientMetadata {
        OAuthClientMetadata(
            clientName: MatrixConfiguration.clientName,
            redirectUri: MatrixConfiguration.oauthRedirectUri,
            clientUri: MatrixConfiguration.clientUri,
            logoUri: nil,
            tosUri: nil,
            policyUri: nil,
            staticRegistrations: [:]
        )
    }
}
