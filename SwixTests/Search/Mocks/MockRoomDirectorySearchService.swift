//
//  MockRoomDirectorySearchService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

@testable import Swix


/// Records every search and page request `RoomDirectoryRepository` makes, and lets a test push
/// result batches through and answer `isAtLastPage()`.
final class MockRoomDirectorySearchService: RoomDirectorySearchServiceProtocol {

    let resultDiffs: AsyncStream<[CollectionDiff<DirectoryRoom>]>

    let diffContinuation: AsyncStream<[CollectionDiff<DirectoryRoom>]>.Continuation

    private(set) var searchCalls: [(filter: String?, viaServerName: String?)] = []

    private(set) var loadNextPageCallCount = 0

    private(set) var shutdownCallCount = 0

    var isAtLastPageValue = false

    var searchError: (any Error)?

    var loadNextPageError: (any Error)?

    var isAtLastPageError: (any Error)?

    init() {
        (resultDiffs, diffContinuation) = AsyncStream<[CollectionDiff<DirectoryRoom>]>.makeStream(bufferingPolicy: .unbounded)
    }

    func search(
        filter       : String?,
        viaServerName: String?
    ) async throws {

        searchCalls.append((filter, viaServerName))

        if let searchError {
            throw searchError
        }
    }

    func loadNextPage() async throws {
        loadNextPageCallCount += 1

        if let loadNextPageError {
            throw loadNextPageError
        }
    }

    func isAtLastPage() async throws -> Bool {
        if let isAtLastPageError {
            throw isAtLastPageError
        }

        return isAtLastPageValue
    }

    func shutdown() {
        shutdownCallCount += 1
    }
}
