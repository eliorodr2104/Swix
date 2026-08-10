//
//  HomeserverLoginMethods.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// Whether a homeserver can drive the sliding sync proxy-less protocol Swix relies on.
enum SlidingSyncSupport: Equatable {

    /// The homeserver advertises native sliding sync.
    case native

    /// The homeserver has no sliding sync at all, so Swix cannot show a room list on it.
    case unsupported

    /// Convenience for the login screen, which refuses a homeserver Swix could not sync with.
    var isSupported: Bool { self == .native }
}

/// What a homeserver told us about itself when asked how it wants users to authenticate.
///
/// This is the domain mirror of the SDK's `HomeserverLoginDetails`, produced by
/// `HomeserverLoginMethodsMapper` so that nothing above the service layer sees an SDK handle.
struct HomeserverLoginMethods: Equatable {

    /// The resolved homeserver URL, which may differ from what the user typed after well-known
    /// discovery (typing `matrix.org` yields `https://matrix-client.matrix.org`).
    let url: String

    /// Whether the classic username and password flow is available.
    let supportsPassword: Bool

    /// Whether the homeserver delegates authentication to an OAuth 2.0 provider.
    let supportsOAuth: Bool

    /// Whether the homeserver only offers legacy SSO, which Swix does not implement.
    let supportsSSO: Bool

    /// The sliding sync flavour the homeserver advertises.
    let slidingSyncVersion: SlidingSyncSupport

    init(
        url               : String,
        supportsPassword  : Bool,
        supportsOAuth     : Bool,
        supportsSSO       : Bool,
        slidingSyncVersion: SlidingSyncSupport
    ) {
        self.url                = url
        self.supportsPassword   = supportsPassword
        self.supportsOAuth      = supportsOAuth
        self.supportsSSO        = supportsSSO
        self.slidingSyncVersion = slidingSyncVersion
    }
}
