//
//  OAuthWebAuthenticatorProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Runs the browser half of an OAuth login and hands back the callback URL, nothing more.
///
/// This lives in the service layer even though it puts a sheet on screen: it owns no view, and the
/// repository above it only ever sees a `URL` come back.
protocol OAuthWebAuthenticatorProtocol {

    /// Presents `url` and waits for the provider to redirect to `callbackScheme`.
    func authenticate(
        url           : URL,
        callbackScheme: String
    ) async throws -> URL
}
