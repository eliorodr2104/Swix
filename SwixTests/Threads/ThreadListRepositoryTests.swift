//
//  ThreadListRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing
@testable import Swix


@Suite("ThreadListRepository")
struct ThreadListRepositoryTests {

    @Test("start() attaches the service and loads the opening page")
    func startAttachesService() async {
        let service = MockThreadListService()
        let subscriptionService = MockThreadSubscriptionService()
        let repository = ThreadListRepository(service: service, subscriptionService: subscriptionService)

        await repository.start()

        #expect(service.startCallCount == 1)
        #expect(repository.failure == nil)
    }

    @Test("a reset diff replaces the whole list")
    func resetDiffReplacesList() async {
        let service = MockThreadListService()
        let subscriptionService = MockThreadSubscriptionService()
        let repository = ThreadListRepository(service: service, subscriptionService: subscriptionService)

        await repository.start()

        let entries = [Self.makeEntry(rootEventID: "$root1"), Self.makeEntry(rootEventID: "$root2")]

        service.diffContinuation.yield([.reset(entries)])

        await Eventually.isTrue { repository.threads.count == 2 }

        #expect(repository.threads.map(\.rootEventID) == ["$root1", "$root2"])
        #expect(!repository.isEmpty)
    }

    @Test("a known subscription survives a later diff batch republishing that row")
    func knownSubscriptionSurvivesRepublish() async {
        let service = MockThreadListService()
        let subscriptionService = MockThreadSubscriptionService()
        let repository = ThreadListRepository(service: service, subscriptionService: subscriptionService)

        await repository.start()

        service.diffContinuation.yield([.reset([Self.makeEntry(rootEventID: "$root1")])])

        await Eventually.isTrue { repository.threads.count == 1 }

        subscriptionService.stubbedSubscription = .subscribed(isAutomatic: false)

        await repository.loadSubscription(forThread: "$root1")

        #expect(repository.threads.first?.subscription == .subscribed(isAutomatic: false))

        // The service republishes the same row, unaware of the subscription the account just read.
        service.diffContinuation.yield([.set(index: 0, element: Self.makeEntry(rootEventID: "$root1"))])

        await Eventually.isTrue { repository.threads.first?.subscription.isKnown == true }

        #expect(repository.threads.first?.subscription == .subscribed(isAutomatic: false))
    }

    @Test("loadSubscription remembers the answer even for a thread not yet in the list")
    func loadSubscriptionRemembersUnknownThread() async {
        let service = MockThreadListService()
        let subscriptionService = MockThreadSubscriptionService()
        let repository = ThreadListRepository(service: service, subscriptionService: subscriptionService)

        await repository.start()

        subscriptionService.stubbedSubscription = .subscribed(isAutomatic: true)

        await repository.loadSubscription(forThread: "$laterThread")

        service.diffContinuation.yield([.reset([Self.makeEntry(rootEventID: "$laterThread")])])

        await Eventually.isTrue { repository.threads.count == 1 }

        #expect(repository.threads.first?.subscription == .subscribed(isAutomatic: true))
    }

    @Test("setSubscription only writes the row once the homeserver has agreed")
    func setSubscriptionWritesRowOnSuccess() async {
        let service = MockThreadListService()
        let subscriptionService = MockThreadSubscriptionService()
        let repository = ThreadListRepository(service: service, subscriptionService: subscriptionService)

        await repository.start()

        service.diffContinuation.yield([.reset([Self.makeEntry(rootEventID: "$root1")])])

        await Eventually.isTrue { repository.threads.count == 1 }

        await repository.setSubscription(true, forThread: "$root1")

        #expect(subscriptionService.setCalls.count == 1)
        #expect(subscriptionService.setCalls.first?.isSubscribed == true)
        #expect(repository.threads.first?.subscription == .subscribed(isAutomatic: false))
    }

    @Test("a failed setSubscription records the failure and leaves the row untouched")
    func setSubscriptionFailureRecordsFailure() async {
        let service = MockThreadListService()
        let subscriptionService = MockThreadSubscriptionService()
        let repository = ThreadListRepository(service: service, subscriptionService: subscriptionService)

        await repository.start()

        service.diffContinuation.yield([.reset([Self.makeEntry(rootEventID: "$root1")])])

        await Eventually.isTrue { repository.threads.count == 1 }

        subscriptionService.setError = ThreadsFailure.subscriptionFailed(Fixtures.sdkErrorInfo())

        await repository.setSubscription(true, forThread: "$root1")

        #expect(repository.failure != nil)
        #expect(repository.threads.first?.subscription == .unknown)
    }

    @Test("loadMore paginates through the service")
    func loadMoreCallsPaginate() async {
        let service = MockThreadListService()
        let subscriptionService = MockThreadSubscriptionService()
        let repository = ThreadListRepository(service: service, subscriptionService: subscriptionService)

        await repository.start()

        service.stateContinuation.yield(.idle(hasReachedEnd: false))

        await Eventually.isTrue { !repository.state.isLoading }

        await repository.loadMore()

        #expect(service.paginateCallCount == 1)
    }

    @Test("loadMore is a no-op once the list has reached its end")
    func loadMoreNoOpAtEnd() async {
        let service = MockThreadListService()
        let subscriptionService = MockThreadSubscriptionService()
        let repository = ThreadListRepository(service: service, subscriptionService: subscriptionService)

        await repository.start()

        service.stateContinuation.yield(.idle(hasReachedEnd: true))

        await Eventually.isTrue { repository.state.hasReachedEnd }

        await repository.loadMore()

        #expect(service.paginateCallCount == 0)
    }

    @Test("refresh resets the service then paginates again")
    func refreshResetsAndPaginates() async {
        let service = MockThreadListService()
        let subscriptionService = MockThreadSubscriptionService()
        let repository = ThreadListRepository(service: service, subscriptionService: subscriptionService)

        await repository.start()
        await repository.refresh()

        #expect(service.resetCallCount == 1)
        #expect(service.paginateCallCount == 1)
    }

    @Test("a service failure surfaces on the repository")
    func startFailureIsRecorded() async {
        let service = MockThreadListService()
        let subscriptionService = MockThreadSubscriptionService()

        service.startError = ThreadsFailure.roomUnavailable(Fixtures.sdkErrorInfo())

        let repository = ThreadListRepository(service: service, subscriptionService: subscriptionService)

        await repository.start()

        #expect(repository.failure != nil)
    }

    @Test("shutdown releases the service")
    func shutdownReleasesService() {
        let service = MockThreadListService()
        let subscriptionService = MockThreadSubscriptionService()
        let repository = ThreadListRepository(service: service, subscriptionService: subscriptionService)

        repository.shutdown()

        #expect(service.shutdownCallCount == 1)
    }

    private static func makeEntry(
        rootEventID: String,
        subscription: ThreadSubscriptionState = .unknown
    ) -> ThreadEntry {

        ThreadEntry(
            rootEventID         : rootEventID,
            rootPreviewText     : "Hello",
            senderName          : "Alice",
            isOwn               : false,
            rootTimestamp       : Date(timeIntervalSince1970: 0),
            lastReplyPreviewText: nil,
            lastReplySenderName : nil,
            lastReplyTimestamp  : nil,
            replyCount          : 0,
            subscription        : subscription
        )
    }
}
