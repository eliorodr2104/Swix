//
//  ThreadListRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation
import os


/// The single source of truth for one room's thread list, and the only writer of `threads`.
///
/// The array is rebuilt exclusively by applying the service's diff batches in order, never by
/// refetching, so the rows stay in exactly the order the SDK put them in. Subscription answers
/// arrive separately and only ever rewrite one field of one row, so they cannot disturb it either.
@Observable
final class ThreadListRepository {

    /// Every thread of the room, in the order the homeserver paginated them.
    private(set) var threads: [ThreadEntry] = []

    /// Whether a page of threads is in flight, and whether any are left.
    private(set) var state: ThreadListState = .idle(hasReachedEnd: false)

    /// The last failure, kept until the next attempt clears it.
    private(set) var failure: ThreadsFailure?

    @ObservationIgnored
    private let service: any ThreadListServiceProtocol

    @ObservationIgnored
    private let subscriptionService: any ThreadSubscriptionServiceProtocol

    @ObservationIgnored
    private let subscriptions = SubscriptionBag()

    @ObservationIgnored
    private var isObserving = false

    // Whatever the homeserver has said about a thread, remembered outside the rows so a diff cannot
    // take it back. See `apply(_:)` for why that is necessary.
    @ObservationIgnored
    private var knownSubscriptions: [String: ThreadSubscriptionState] = [:]

    init(
        service            : any ThreadListServiceProtocol,
        subscriptionService: any ThreadSubscriptionServiceProtocol
    ) {
        self.service             = service
        self.subscriptionService = subscriptionService
    }

    /// The room whose threads these are.
    var roomID: String {
        service.roomID
    }

    /// Whether the room has no threads at all.
    var isEmpty: Bool {
        threads.isEmpty
    }

    /// Starts observing the thread list service on first call, then attaches it and loads the
    /// opening page.
    func start() async {
        observeServiceIfNeeded()

        await run {
            try await service.start()
        }
    }

    /// Asks for the next page of threads, for when the user reaches the end of the list.
    ///
    /// Nothing happens while a page is already in flight or once the list is exhausted: the SDK
    /// would no op anyway, and this way the spinner does not flicker.
    func loadMore() async {
        guard state.canLoadMore else {
            return
        }

        await run {
            try await service.paginate()
        }
    }

    /// Throws the list away and loads it again from the first page, for a pull to refresh.
    ///
    /// The subscription answers are kept: they were never part of the list, and they are still just
    /// as true after it has been rebuilt.
    func refresh() async {
        await service.reset()

        await run {
            try await service.paginate()
        }
    }

    /// Asks the homeserver whether the account follows one thread and patches that row with the
    /// answer. A thread this list does not hold is remembered anyway, in case it arrives later.
    func loadSubscription(forThread rootEventID: String) async {
        await run {
            let subscription = try await subscriptionService.loadSubscription(
                roomID     : roomID,
                rootEventID: rootEventID
            )

            apply(subscription, toThread: rootEventID)
        }
    }

    /// Starts or stops following a thread, then patches that row.
    ///
    /// The row is written only once the homeserver has agreed: a toggle that flips optimistically
    /// and then flips back is worse than one that takes a moment to move.
    func setSubscription(
        _ isSubscribed       : Bool,
        forThread rootEventID: String
    ) async {

        await run {
            try await subscriptionService.setSubscription(
                isSubscribed,
                roomID     : roomID,
                rootEventID: rootEventID
            )

            apply(
                isSubscribed ? .subscribed(isAutomatic: false) : .unsubscribed,
                toThread: rootEventID
            )
        }
    }

    /// Releases every subscription this repository and its service own. Called once, by whoever
    /// created them, when the thread list is closed.
    func shutdown() {
        subscriptions.cancelAll()
        service.shutdown()

        isObserving = false
    }

    private func observeServiceIfNeeded() {
        guard !isObserving else {
            return
        }

        isObserving = true

        subscriptions.retain(
            Task { [weak self, diffs = service.entryDiffs] in
                for await batch in diffs {
                    self?.apply(batch)
                }
            }
        )

        subscriptions.retain(
            Task { [weak self, states = service.listStates] in
                for await state in states {
                    self?.state = state
                }
            }
        )
    }

    /// The list republishes a whole row every time a reply lands on that thread, and what it
    /// publishes never carries a subscription: applying a batch straight would quietly reset every
    /// toggle the user had just moved. The answers are painted back on here instead.
    private func apply(_ batch: [CollectionDiff<ThreadEntry>]) {
        threads.applyDiffs(batch)

        guard !knownSubscriptions.isEmpty else {
            return
        }

        for index in threads.indices {
            guard let subscription = knownSubscriptions[threads[index].rootEventID] else {
                continue
            }

            threads[index].subscription = subscription
        }
    }

    /// Records an answer and paints it on the row it belongs to. It is recorded even when no row
    /// matches, because the thread may well be on a page nobody has asked for yet.
    private func apply(
        _ subscription      : ThreadSubscriptionState,
        toThread rootEventID: String
    ) {

        knownSubscriptions[rootEventID] = subscription

        for index in threads.indices where threads[index].rootEventID == rootEventID {
            threads[index].subscription = subscription
        }
    }

    private func run(_ action: () async throws -> Void) async {
        do {
            try await action()

            failure = nil
        } catch {
            store(ThreadsFailure.wrapping(error))
        }
    }

    private func store(_ threadsFailure: ThreadsFailure) {
        Log.timeline.error("Thread list failure: \(threadsFailure.message, privacy: .public)")

        failure = threadsFailure
    }
}
