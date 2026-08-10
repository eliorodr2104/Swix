//
//  MockIgnoredUsersService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

@testable import Swix


/// Records every ignore list read and write `IgnoredUsersRepository` makes, and lets a test push
/// later list updates through `ignoredUserIDsStream`.
final class MockIgnoredUsersService: IgnoredUsersServiceProtocol {

    let ignoredUserIDsStream: AsyncStream<[String]>

    let ignoredUserIDsContinuation: AsyncStream<[String]>.Continuation

    var stubbedIgnoredUserIDs: [String] = []

    private(set) var ignoreCalls: [String] = []

    private(set) var unignoreCalls: [String] = []

    private(set) var startObservingCallCount = 0

    private(set) var shutdownCallCount = 0

    var fetchError: (any Error)?

    var writeError: (any Error)?

    var startObservingError: (any Error)?

    init() {
        (ignoredUserIDsStream, ignoredUserIDsContinuation) = AsyncStream<[String]>.makeStream(bufferingPolicy: .unbounded)
    }

    func fetchIgnoredUserIDs() async throws -> [String] {
        if let fetchError {
            throw fetchError
        }

        return stubbedIgnoredUserIDs
    }

    func ignore(userID: String) async throws {
        ignoreCalls.append(userID)

        if let writeError {
            throw writeError
        }
    }

    func unignore(userID: String) async throws {
        unignoreCalls.append(userID)

        if let writeError {
            throw writeError
        }
    }

    func startObservingIgnoredUsers() throws {
        startObservingCallCount += 1

        if let startObservingError {
            throw startObservingError
        }
    }

    func shutdown() {
        shutdownCallCount += 1
    }
}
