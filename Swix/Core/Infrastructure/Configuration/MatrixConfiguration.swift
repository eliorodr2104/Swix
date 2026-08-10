//
//  MatrixConfiguration.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// App-wide constants the Core needs when talking to the SDK: identity strings, the OAuth
/// redirect, the default call server, and the page sizes shared across several features.
enum MatrixConfiguration {

    /// Sent as `ClientBuilder.userAgent`.
    static let userAgent = "Swix/1.0 (iOS)"

    /// Sent as the OAuth client metadata's `client_name`.
    static let clientName = "Swix"

    /// Sent as the OAuth client metadata's `client_uri`, and shown to the user on the homeserver's
    /// consent screen. Its host is what the redirect scheme below has to be derived from.
    static let clientUri = "https://eliorodr2104.github.io/swix"

    /// Custom URL scheme the app registers to receive the OAuth authorization callback.
    ///
    /// A homeserver registering a public client dynamically only accepts a scheme that is the
    /// reverse DNS of the `client_uri` host, which is why these three constants move together.
    static let oauthRedirectScheme = "io.github.eliorodr2104"

    /// Full OAuth `redirect_uri`, matching `oauthRedirectScheme`.
    static let oauthRedirectUri = "io.github.eliorodr2104:/callback"

    /// Default Element Call deployment used when a room has no other widget configured.
    static let elementCallBaseUrl = "https://call.element.io"

    /// Subdirectory of a session's cache path where the Tantivy search index lives.
    static let searchIndexSubpath = "search-index"

    /// Rooms fetched per page from `RoomListEntriesWithDynamicAdaptersResult.addOnePage()`.
    static let roomListPageSize: UInt32 = 20

    /// Events requested per backward/forward timeline pagination call.
    static let timelinePaginationPageSize: UInt16 = 30

    /// Results requested per page from room directory and user search endpoints.
    static let directorySearchPageSize: UInt32 = 20
}
