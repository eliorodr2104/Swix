//
//  UserSearchService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// The default `UserSearchServiceProtocol`, built on `Client.searchUsers(searchTerm:limit:)`.
struct UserSearchService: UserSearchServiceProtocol {

    private let clientService: any ClientServiceProtocol

    init(clientService: any ClientServiceProtocol) {
        self.clientService = clientService
    }

    func searchUsers(
        matching term: String,
        limit        : Int
    ) async throws -> [FoundUser] {
        guard let client = clientService.sdkClient else {
            throw SearchFailure.noActiveClient
        }

        do {
            let results = try await client.searchUsers(searchTerm: term, limit: UInt64(limit))

            return FoundUserMapper.makeUsers(from: results)
        } catch {
            throw SearchFailure.userSearchFailed(SDKErrorInfo(error))
        }
    }
}
