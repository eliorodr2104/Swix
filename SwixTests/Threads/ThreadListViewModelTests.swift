//
//  ThreadListViewModelTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing
@testable import Swix


@Suite("ThreadListViewModel")
struct ThreadListViewModelTests {

    @Test("toggling an unknown subscription reads it instead of flipping it")
    func toggleUnknownSubscriptionReads() async {
        let service = MockThreadListService()
        let subscriptionService = MockThreadSubscriptionService()
        let repository = ThreadListRepository(service: service, subscriptionService: subscriptionService)
        let viewModel = ThreadListViewModel(repository: repository)

        subscriptionService.stubbedSubscription = .subscribed(isAutomatic: false)

        let entry = Self.makeEntry(rootEventID: "$root1", subscription: .unknown)

        await viewModel.toggleSubscription(for: entry)

        #expect(subscriptionService.loadCalls.count == 1)
        #expect(subscriptionService.setCalls.isEmpty)
    }

    @Test("toggling a known subscription flips it")
    func toggleKnownSubscriptionFlips() async {
        let service = MockThreadListService()
        let subscriptionService = MockThreadSubscriptionService()
        let repository = ThreadListRepository(service: service, subscriptionService: subscriptionService)
        let viewModel = ThreadListViewModel(repository: repository)

        let entry = Self.makeEntry(rootEventID: "$root1", subscription: .unsubscribed)

        await viewModel.toggleSubscription(for: entry)

        #expect(subscriptionService.setCalls.count == 1)
        #expect(subscriptionService.setCalls.first?.isSubscribed == true)
        #expect(subscriptionService.loadCalls.isEmpty)
    }

    @Test("a pagination failure is surfaced as a titled, retryable failure")
    func paginationFailureBecomesUserFacing() async {
        let service = MockThreadListService()
        let subscriptionService = MockThreadSubscriptionService()
        let repository = ThreadListRepository(service: service, subscriptionService: subscriptionService)
        let viewModel = ThreadListViewModel(repository: repository)

        await viewModel.start()

        service.paginateError = ThreadsFailure.paginationFailed(Fixtures.sdkErrorInfo(kind: .network))

        await viewModel.loadMore()

        #expect(viewModel.failure?.title == "Could not load more threads")
        #expect(viewModel.failure?.isRetryable == true)
    }

    @Test("shutdown clears the failure and releases the repository")
    func shutdownClearsFailure() async {
        let service = MockThreadListService()
        let subscriptionService = MockThreadSubscriptionService()

        service.startError = ThreadsFailure.roomUnavailable(Fixtures.sdkErrorInfo())

        let repository = ThreadListRepository(service: service, subscriptionService: subscriptionService)
        let viewModel = ThreadListViewModel(repository: repository)

        await viewModel.start()

        #expect(viewModel.failure != nil)

        viewModel.shutdown()

        #expect(viewModel.failure == nil)
        #expect(service.shutdownCallCount == 1)
    }

    private static func makeEntry(
        rootEventID : String,
        subscription: ThreadSubscriptionState
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
