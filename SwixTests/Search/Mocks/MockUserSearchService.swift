//
//  MockUserSearchService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

@testable import Swix


/// Records every term `UserSearchRepository` asked the directory for, answering from a stubbed
/// result list by default. Setting `searchHandler` hands full control of the answer, including its
/// timing, to the test, which is what exercises the repository's stale-answer guard: an older
/// call can be made to resolve after a newer one already has.
final class MockUserSearchService: UserSearchServiceProtocol {

    private(set) var searchCalls: [(term: String, limit: Int)] = []

    var stubbedUsers: [FoundUser] = []

    var failureToThrow: (any Error)?

    var searchHandler: (@Sendable (String, Int) async throws -> [FoundUser])?

    func searchUsers(
        matching term: String,
        limit        : Int
    ) async throws -> [FoundUser] {

        searchCalls.append((term, limit))

        if let searchHandler {
            return try await searchHandler(term, limit)
        }

        if let failureToThrow {
            throw failureToThrow
        }

        return stubbedUsers
    }
}
