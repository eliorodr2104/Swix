//
//  OAuthAuthorizationRequest.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation

/// Everything the web authenticator needs to run an OAuth round trip, with no SDK handle attached.
///
/// The SDK's `OAuthAuthorizationData` has to survive until the callback comes back or the flow is
/// aborted, so it stays inside `AuthenticationService` and `id` is the token that stands for it.
struct OAuthAuthorizationRequest: Equatable, Identifiable {

    /// Opaque token identifying the authorization the service is holding open.
    let id: UUID

    /// The page to present, built by the homeserver's OAuth provider.
    let authorizationURL: URL

    /// Custom URL scheme the provider will redirect to once the user is done.
    let callbackScheme: String

    init(
        id              : UUID = UUID(),
        authorizationURL: URL,
        callbackScheme  : String
    ) {
        self.id               = id
        self.authorizationURL = authorizationURL
        self.callbackScheme   = callbackScheme
    }
}
