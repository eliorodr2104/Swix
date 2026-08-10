//
//  OpenIdTokenService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK

/// The default `OpenIdTokenServiceProtocol`, wired directly on the live SDK client.
final class OpenIdTokenService: OpenIdTokenServiceProtocol {

    private let clientService: any ClientServiceProtocol

    init(clientService: any ClientServiceProtocol) {
        self.clientService = clientService
    }

    func requestToken() async throws -> OpenIdTokenInfo {
        guard let client = clientService.sdkClient else {
            throw CallFailure.noActiveClient
        }

        do {
            let token = try await client.requestOpenidToken()

            return OpenIdTokenInfo(
                accessToken     : token.accessToken,
                tokenType       : token.tokenType,
                matrixServerName: token.matrixServerName,
                expiresInSeconds: token.expiresInSeconds
            )
            
        } catch {
            throw CallFailure.openIdTokenFailed(SDKErrorInfo(error))
        }
    }
}
