//
//  MockThreadListService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

@testable import Swix


/// Records every call `ThreadListRepository` makes and lets a test push diff batches and list
/// states through whenever it wants, rather than only at subscription time.
final class MockThreadListService: ThreadListServiceProtocol {

    let roomID: String

    let entryDiffs: AsyncStream<[CollectionDiff<ThreadEntry>]>

    let listStates: AsyncStream<ThreadListState>

    let diffContinuation: AsyncStream<[CollectionDiff<ThreadEntry>]>.Continuation

    let stateContinuation: AsyncStream<ThreadListState>.Continuation

    private(set) var startCallCount = 0

    private(set) var paginateCallCount = 0

    private(set) var resetCallCount = 0

    private(set) var shutdownCallCount = 0

    var startError: (any Error)?

    var paginateError: (any Error)?

    init(roomID: String = "!room:example.org") {
        self.roomID = roomID

        (entryDiffs, diffContinuation) = AsyncStream<[CollectionDiff<ThreadEntry>]>.makeStream(bufferingPolicy: .unbounded)
        (listStates, stateContinuation) = AsyncStream<ThreadListState>.makeStream(bufferingPolicy: .unbounded)
    }

    func start() async throws {
        startCallCount += 1

        if let startError {
            throw startError
        }
    }

    func paginate() async throws {
        paginateCallCount += 1

        if let paginateError {
            throw paginateError
        }
    }

    func reset() async {
        resetCallCount += 1
    }

    func shutdown() {
        shutdownCallCount += 1
    }
}
