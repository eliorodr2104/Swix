//
//  AuthenticationFlow.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// The login screen a homeserver deserves, decided once from what it advertises.
enum AuthenticationFlow: Equatable {

    /// A username and password form, the usual case on a self hosted Synapse.
    case password

    /// A round trip through the homeserver's OAuth provider in a web sheet.
    case oauth

    /// Nothing Swix can drive: legacy SSO only, or no sliding sync to sync with afterwards.
    case unsupported

    /// Picks the flow to show for a homeserver.
    ///
    /// OAuth wins whenever it is offered because matrix.org accepts nothing else from new clients,
    /// and a homeserver that offers both considers the password flow legacy.
    static func preferred(for methods: HomeserverLoginMethods) -> AuthenticationFlow {
        guard methods.slidingSyncVersion.isSupported else {
            return .unsupported
        }

        if methods.supportsOAuth {
            return .oauth
        }

        if methods.supportsPassword {
            return .password
        }

        return .unsupported
    }
}
