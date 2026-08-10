//
//  MessageSearchRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing
@testable import Swix


@Suite("MessageSearchRepository")
struct MessageSearchRepositoryTests {

    @Test("a new query is forwarded to the service and starts loading")
    func newQueryForwardsToService() async {
        let service = MockMessageSearchService()
        let repository = MessageSearchRepository(service: service)

        await repository.search(query: "hello")

        #expect(service.queries == ["hello"])
        #expect(repository.loadState == .loading)
    }

    @Test("repeating the query that is already loaded does nothing")
    func repeatingQueryIsANoOp() async {
        let service = MockMessageSearchService()
        let repository = MessageSearchRepository(service: service)

        await repository.search(query: "hello")
        await repository.search(query: "hello")

        #expect(service.queries == ["hello"])
    }

    @Test("an empty query clears the results without calling the service")
    func emptyQueryClears() async {
        let service = MockMessageSearchService()
        let repository = MessageSearchRepository(service: service)

        await repository.search(query: "hello")
        await repository.search(query: "   ")

        #expect(service.queries == ["hello"])
        #expect(repository.loadState == .idle)
        #expect(repository.results.isEmpty)
    }

    @Test("result diffs from the service are applied to results")
    func resultDiffsAreApplied() async {
        let service = MockMessageSearchService()
        let repository = MessageSearchRepository(service: service)

        await repository.search(query: "hello")

        service.diffContinuation.yield([.reset([Self.makeResult(eventID: "$a")])])

        await Eventually.isTrue { !repository.results.isEmpty }

        #expect(repository.results.map(\.eventID) == ["$a"])
    }

    @Test("loadMore is a no-op once the query is empty or the state forbids it")
    func loadMoreRespectsState() async {
        let service = MockMessageSearchService()
        let repository = MessageSearchRepository(service: service)

        await repository.loadMore()

        #expect(service.paginateCallCount == 0)

        await repository.search(query: "hello")

        service.loadStateContinuation.yield(.loaded(hasMoreResults: true))

        await Eventually.isTrue { repository.loadState.canLoadMore }

        await repository.loadMore()

        #expect(service.paginateCallCount == 1)
    }

    @Test("a query failure records the failure and stops the spinner")
    func queryFailureRecordsFailure() async {
        let service = MockMessageSearchService()

        service.queryError = SearchFailure.queryFailed(Fixtures.sdkErrorInfo())

        let repository = MessageSearchRepository(service: service)

        await repository.search(query: "hello")

        #expect(repository.failure != nil)
        #expect(repository.loadState == .loaded(hasMoreResults: false))
    }

    @Test("clear drops the query and every result without touching the subscriptions")
    func clearDropsQueryAndResults() async {
        let service = MockMessageSearchService()
        let repository = MessageSearchRepository(service: service)

        await repository.search(query: "hello")

        service.diffContinuation.yield([.reset([Self.makeResult(eventID: "$a")])])

        await Eventually.isTrue { !repository.results.isEmpty }

        repository.clear()

        #expect(repository.results.isEmpty)
        #expect(repository.loadState == .idle)

        // Clearing must not have released the subscription: the same query can run again.
        await repository.search(query: "hello")

        #expect(service.queries == ["hello", "hello"])
    }

    @Test("shutdown releases the service")
    func shutdownReleasesService() {
        let service = MockMessageSearchService()
        let repository = MessageSearchRepository(service: service)

        repository.shutdown()

        #expect(service.shutdownCallCount == 1)
    }

    private static func makeResult(eventID: String) -> MessageSearchResult {
        MessageSearchResult(
            roomID           : "!room:example.org",
            roomName         : "Room",
            eventID          : eventID,
            snippetText      : "hello world",
            sender           : "@alice:example.org",
            senderDisplayName: "Alice",
            timestamp        : Date(timeIntervalSince1970: 0)
        )
    }
}
