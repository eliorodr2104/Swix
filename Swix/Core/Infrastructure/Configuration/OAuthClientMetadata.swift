//
//  OAuthClientMetadata.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// SDK-free mirror of `MatrixRustSDK.OAuthConfiguration`'s fields.
///
/// Kept here so Configuration/ never needs to import MatrixRustSDK; the Authentication service
/// maps this 1:1 onto the SDK struct right before calling `urlForOauth`.
struct OAuthClientMetadata {

    let clientName: String?
    let redirectUri: String
    let clientUri: String
    let logoUri: String?
    let tosUri: String?
    let policyUri: String?
    let staticRegistrations: [String: String]
}
