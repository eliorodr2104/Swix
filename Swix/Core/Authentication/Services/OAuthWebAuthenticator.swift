//
//  OAuthWebAuthenticator.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import AuthenticationServices
import Foundation
import UIKit


/// `ASWebAuthenticationSession` wrapped in async/await.
final class OAuthWebAuthenticator: OAuthWebAuthenticatorProtocol {

    // The session cancels itself as soon as it is deallocated, so it has to outlive the call that
    // started it and live exactly as long as the continuation it will resume.
    private var session: ASWebAuthenticationSession?

    private let contextProvider = PresentationContextProvider()

    init() {}

    func authenticate(
        url           : URL,
        callbackScheme: String
    ) async throws -> URL {
        
        try await withCheckedThrowingContinuation { continuation in
            
            let session = ASWebAuthenticationSession(
                url              : url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                
                self.session = nil

                guard let callbackURL else {
                    continuation.resume(throwing: Self.failure(for: error))

                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = contextProvider

            // Keeping the shared browser cookies is what lets a user who is already signed in with
            // the provider go through the sheet without typing anything again.
            session.prefersEphemeralWebBrowserSession = false

            self.session = session

            guard session.start() else {
                self.session = nil

                continuation.resume(
                    throwing: AuthenticationFailure.sdk(
                        SDKErrorInfo(
                            kind   : .unknown,
                            message: "The sign in page could not be opened.",
                            details: url.absoluteString
                        )
                    )
                )

                return
            }
        }
    }

    private static func failure(
        for error: (any Error)?
    ) -> AuthenticationFailure {
        
        guard let error else {
            return .oauthCallbackMalformed
        }

        guard let sessionError = error as? ASWebAuthenticationSessionError, sessionError.code == .canceledLogin else {
            
            return .sdk(
                SDKErrorInfo(
                    kind   : .unknown,
                    message: error.localizedDescription,
                    details: nil
                )
            )
        }

        return .oauthCancelledByUser
    }
}

/// Anchors the authentication sheet to the window the app is actually showing.
private final class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {

    func presentationAnchor(
        for session: ASWebAuthenticationSession
    ) -> ASPresentationAnchor {
        
        let scenes = UIApplication.shared.connectedScenes.compactMap {
            $0 as? UIWindowScene
        }

        guard let scene = scenes.first(
            where: { $0.activationState == .foregroundActive }
        ) ?? scenes.first else {
            return ASPresentationAnchor(frame: .zero)
        }

        return scene.keyWindow ?? ASPresentationAnchor(windowScene: scene)
    }
}
