//
//  MockMessageSearchService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

@testable import Swix


/// Records every query and page request `MessageSearchRepository` makes, and lets a test push
/// result batches and load states through at will.
final class MockMessageSearchService: MessageSearchServiceProtocol {

    let resultDiffs: AsyncStream<[CollectionDiff<MessageSearchResult>]>

    let loadStates: AsyncStream<SearchLoadState>

    let diffContinuation: AsyncStream<[CollectionDiff<MessageSearchResult>]>.Continuation

    let loadStateContinuation: AsyncStream<SearchLoadState>.Continuation

    private(set) var queries: [String] = []

    private(set) var paginateCallCount = 0

    private(set) var shutdownCallCount = 0

    var queryError: (any Error)?

    var paginateError: (any Error)?

    init() {
        (resultDiffs, diffContinuation) = AsyncStream<[CollectionDiff<MessageSearchResult>]>.makeStream(bufferingPolicy: .unbounded)
        (loadStates, loadStateContinuation) = AsyncStream<SearchLoadState>.makeStream(bufferingPolicy: .unbounded)
    }

    func setQuery(_ query: String) async throws {
        queries.append(query)

        if let queryError {
            throw queryError
        }
    }

    func paginate() async throws {
        paginateCallCount += 1

        if let paginateError {
            throw paginateError
        }
    }

    func shutdown() {
        shutdownCallCount += 1
    }
}
