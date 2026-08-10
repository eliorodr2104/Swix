//
//  AuthenticationService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import MatrixRustSDK
import os

/// Drives a login from the moment a homeserver is typed to the moment a client holds a session.
///
/// Discovery is folded in here rather than living in its own service because both need the very
/// same client: building a second one just to ask what the homeserver supports would create, and
/// then have to delete, a whole set of encrypted stores.
protocol AuthenticationServiceProtocol {

    /// What the last discovered homeserver advertised, kept so a flow can be picked more than once.
    var loginMethods: HomeserverLoginMethods? { get }

    /// Builds the client Swix will keep if the login succeeds, and asks it how to sign in.
    ///
    /// `storeIdentity` is non nil only when an account we already know is signing back in after a
    /// soft logout, so that the new session lands on the crypto store its device keys belong to.
    func discover(
        homeserver   : String,
        storeIdentity: SessionStoreIdentity?
    ) async throws -> HomeserverLoginMethods

    /// Signs in with a username and a password. The client stays owned by the client service.
    func loginWithPassword(
        homeserver   : String,
        storeIdentity: SessionStoreIdentity?,
        credentials: PasswordCredentials
    ) async throws

    /// Asks the homeserver for the page to present, and holds the authorization open. The intent
    /// picks between the provider's sign in and account creation forms.
    func startOAuth(
        homeserver   : String,
        storeIdentity: SessionStoreIdentity?,
        intent       : OAuthIntent
    ) async throws -> OAuthAuthorizationRequest

    /// Finishes the OAuth login with the URL the provider redirected to.
    func completeOAuth(callbackURL: URL) async throws

    /// Tells the homeserver to forget the authorization Swix asked for and never used.
    func abortOAuth() async

    /// Throws away the pending login: the authorization, the client and the stores it created.
    func cancel() async
}

/// The default `AuthenticationServiceProtocol`, driving the SDK client owned by `ClientService`.
final class AuthenticationService: AuthenticationServiceProtocol {

    private(set) var loginMethods: HomeserverLoginMethods?

    private let clientService: any ClientServiceProtocol

    // The authorization has to survive between the two halves of the OAuth round trip, and the
    // request published to the caller carries only its identifier.
    private var pendingAuthorization: (
        id  : UUID,
        data: OAuthAuthorizationData
    )?

    private var preparedHomeserver: String?

    private var preparedStoreIdentifier: String?

    init(clientService: any ClientServiceProtocol) {
        self.clientService = clientService
    }

    func discover(
        homeserver   : String,
        storeIdentity: SessionStoreIdentity?
    ) async throws -> HomeserverLoginMethods {
        
        let client = try await prepareClient(
            homeserver   : homeserver,
            storeIdentity: storeIdentity
        )

        let methods = HomeserverLoginMethodsMapper.makeLoginMethods(
            from: await client.homeserverLoginDetails()
        )

        loginMethods = methods

        Log.auth.notice(
            "Homeserver discovered, password: \(methods.supportsPassword, privacy: .public), oauth: \(methods.supportsOAuth, privacy: .public)"
        )

        return methods
    }

    func loginWithPassword(
        homeserver   : String,
        storeIdentity: SessionStoreIdentity?,
        credentials  : PasswordCredentials
    ) async throws {
    
        guard credentials.isValid else {
            throw AuthenticationFailure.invalidCredentials
        }

        let client = try await prepareClient(
            homeserver   : homeserver,
            storeIdentity: storeIdentity
        )

        do {
            try await client.login(
                username         : credentials.username,
                password         : credentials.password,
                initialDeviceName: MatrixConfiguration.clientName,
                deviceId         : nil
            )
            
        } catch { throw Self.makePasswordFailure(error) }
    }

    func startOAuth(
        homeserver   : String,
        storeIdentity: SessionStoreIdentity?,
        intent       : OAuthIntent
    ) async throws -> OAuthAuthorizationRequest {

        let client = try await prepareClient(
            homeserver   : homeserver,
            storeIdentity: storeIdentity
        )

        await abortOAuth()

        let data: OAuthAuthorizationData

        do {
            // Signing in passes no prompt on purpose: the provider then applies its own default,
            // which keeps an already signed in browser session from retyping anything.
            data = try await client.urlForOauth(
                oauthConfiguration: Self.makeOAuthConfiguration(),
                prompt            : intent == .signUp ? .create : nil,
                loginHint         : nil,
                deviceId          : nil,
                additionalScopes  : nil
            )

        } catch { throw AuthenticationFailure.wrapping(error) }

        let loginURL = data.loginUrl()

        guard let authorizationURL = URL(string: loginURL) else {
            await client.abortOauthAuth(authorizationData: data)

            throw AuthenticationFailure.sdk(SDKErrorInfo(
                kind  : .unknown,
                message: "The homeserver returned an authorization address Swix could not read.",
                details: loginURL)
            )
        }

        let request = OAuthAuthorizationRequest(
            authorizationURL: authorizationURL,
            callbackScheme  : MatrixConfiguration.oauthRedirectScheme
        )

        pendingAuthorization = (id: request.id, data: data)

        return request
    }

    func completeOAuth(callbackURL: URL) async throws {
        guard let client = clientService.sdkClient, pendingAuthorization != nil else {
            throw AuthenticationFailure.oauthCallbackMalformed
        }

        do {
            try await client.loginWithOauthCallback(callbackUrl: callbackURL.absoluteString)
            
        } catch { throw Self.makeOAuthFailure(error) }

        pendingAuthorization = nil
    }

    func abortOAuth() async {
        guard let pending = pendingAuthorization else {
            return
        }

        pendingAuthorization = nil

        guard let client = clientService.sdkClient else {
            return
        }

        await client.abortOauthAuth(authorizationData: pending.data)
    }

    func cancel() async {
        await abortOAuth()

        loginMethods            = nil
        preparedHomeserver      = nil
        preparedStoreIdentifier = nil

        clientService.abandonPendingClient()
    }

    /// Reuses the client built for the previous step whenever it points at the same homeserver and
    /// the same stores, so discovering and then signing in costs a single client.
    private func prepareClient(
        homeserver   : String,
        storeIdentity: SessionStoreIdentity?
    ) async throws -> Client {
    
        let identifier = storeIdentity?.directoryIdentifier

        if let client = clientService.sdkClient, preparedHomeserver == homeserver, preparedStoreIdentifier == identifier {
            return client
        }

        clientService.abandonPendingClient()

        preparedHomeserver      = nil
        preparedStoreIdentifier = nil
        loginMethods            = nil

        do {
            let client: Client

            if let storeIdentity {
                client = try await clientService.makeClient(
                    homeserver  : homeserver,
                    storeIdentity: storeIdentity
                )
                
            } else {
                client = try await clientService.makeClient(homeserver: homeserver)
            }

            preparedHomeserver      = homeserver
            preparedStoreIdentifier = identifier

            return client
            
        } catch {
            throw AuthenticationFailure.homeserverNotReachable(Self.makeErrorInfo(error))
        }
    }

    /// The metadata is assembled outside the SDK so `Configuration/` stays SDK free; this is the
    /// one place where the two shapes meet.
    private static func makeOAuthConfiguration() -> OAuthConfiguration {
        let metadata = OAuthConfigurationProvider.makeMetadata()

        return OAuthConfiguration(
            clientName         : metadata.clientName,
            redirectUri        : metadata.redirectUri,
            clientUri          : metadata.clientUri,
            logoUri            : metadata.logoUri,
            tosUri             : metadata.tosUri,
            policyUri          : metadata.policyUri,
            staticRegistrations: metadata.staticRegistrations
        )
    }

    private static func makePasswordFailure(_ error: any Error) -> AuthenticationFailure {
        let info = makeErrorInfo(error)

        guard info.kind == .forbidden else {
            return .sdk(info)
        }

        return .invalidCredentials
    }

    private static func makeOAuthFailure(_ error: any Error) -> AuthenticationFailure {
        guard let oauthError = error as? OAuthError else {
            return .wrapping(error)
        }

        return switch oauthError {
            case .Cancelled                : .oauthCancelledByUser
            case .CallbackUrlInvalid       : .oauthCallbackMalformed
            case .NotSupported             : .unsupportedLoginFlow
            case .MetadataInvalid, .Generic: .sdk(SDKErrorInfo(oauthError))
        }
    }

    /// Failures raised by the session layer arrive classified already, so their info is unwrapped
    /// instead of being reflected into an opaque description.
    private static func makeErrorInfo(_ error: any Error) -> SDKErrorInfo {
        (error as? any SwixFailure)?.sdkInfo ?? SDKErrorInfo(error)
    }
}
