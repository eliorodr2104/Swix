//
//  ThreadViewModel.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation


/// One thread's screen: the conversation, plus the one thing a thread has and a room does not.
///
/// A thread is an ordinary timeline focused on its root event, so nothing about the conversation is
/// rebuilt here: `chat` is a `ChatViewModel` over a thread focused timeline, and every message,
/// reaction, poll and receipt already works through it. What is left for this type is the thread's
/// subscription, and knowing when to build and drop the conversation.
///
/// The two failure properties are not the same thing: `chat.failure` is what went wrong with a
/// message, `failure` is what went wrong with the thread.
@Observable
final class ThreadViewModel {

    /// The conversation, absent until `open()` has built it.
    private(set) var chat: ChatViewModel?

    /// Whether the account follows this thread, `.unknown` until the homeserver has answered.
    private(set) var subscription: ThreadSubscriptionState = .unknown

    /// The failure to present. Views clear it by setting it back to nil.
    var failure: UserFacingFailure?

    /// The room the thread lives in.
    let roomID: String

    /// The event the thread hangs off, which is how every thread operation names it.
    let rootEventID: String

    @ObservationIgnored
    private let timelineProvider: any TimelineProviderProtocol

    @ObservationIgnored
    private let subscriptionService: any ThreadSubscriptionServiceProtocol

    init(
        roomID             : String,
        rootEventID        : String,
        timelineProvider   : any TimelineProviderProtocol,
        subscriptionService: any ThreadSubscriptionServiceProtocol
    ) {
        self.roomID              = roomID
        self.rootEventID         = rootEventID
        self.timelineProvider    = timelineProvider
        self.subscriptionService = subscriptionService
    }

    /// Whether the conversation is ready to render.
    var isOpen: Bool {
        chat != nil
    }

    /// Whether the account follows this thread right now.
    var isSubscribed: Bool {
        subscription.isSubscribed
    }

    /// Builds the thread's conversation and reads its subscription. Called when the screen appears.
    ///
    /// The subscription is read even when the timeline could not be built, because it is a separate
    /// request against the room and there is no reason for one failure to hide the other answer.
    func open() async {
        await openTimeline()
        await loadSubscription()
    }

    /// Asks the homeserver whether the account follows this thread.
    func loadSubscription() async {
        do {
            subscription = try await subscriptionService.loadSubscription(
                roomID     : roomID,
                rootEventID: rootEventID
            )

            failure = nil
        } catch {
            store(ThreadsFailure.wrapping(error))
        }
    }

    /// Starts or stops following this thread.
    ///
    /// The state moves only once the homeserver has agreed: a switch that flips optimistically and
    /// then flips back is worse than one that takes a moment to move.
    func setSubscribed(_ isSubscribed: Bool) async {
        do {
            try await subscriptionService.setSubscription(
                isSubscribed,
                roomID     : roomID,
                rootEventID: rootEventID
            )

            subscription = isSubscribed ? .subscribed(isAutomatic: false) : .unsubscribed
            failure = nil
        } catch {
            store(ThreadsFailure.wrapping(error))
        }
    }

    /// Follows the thread, or stops following it when the account already does.
    ///
    /// A subscription nobody has read yet is asked about instead of flipped, so the switch never
    /// takes the user somewhere they did not choose.
    func toggleSubscription() async {
        guard subscription.isKnown else {
            await loadSubscription()

            return
        }

        await setSubscribed(!isSubscribed)
    }

    /// Tears the conversation down when the screen goes away.
    ///
    /// The timeline itself stays in the provider's cache, keyed by room and root event, so whoever
    /// owns the provider still has to `release(roomID:)` it when the user leaves the room for good.
    /// A thread screen that comes back needs a fresh `ThreadViewModel`, and should be given a
    /// released provider entry: reattaching a timeline that was shut down puts a second consumer on
    /// streams that only support one.
    func shutdown() {
        chat?.shutdown()

        chat = nil
        subscription = .unknown
        failure = nil
    }

    /// Opening the same thread twice is a no op: the conversation on screen is already the one the
    /// provider would hand back.
    private func openTimeline() async {
        guard chat == nil else {
            return
        }

        do {
            let service = try await timelineProvider.makeThreadTimeline(
                roomID     : roomID,
                rootEventID: rootEventID
            )

            let chat = ChatViewModel(repository: TimelineRepository(service: service))

            self.chat = chat

            await chat.start()

            failure = nil
        } catch {
            store(ThreadsFailure.wrapping(error))
        }
    }

    private func store(_ threadsFailure: ThreadsFailure) {
        failure = UserFacingFailure(
            title      : Self.title(for: threadsFailure),
            message    : threadsFailure.message,
            isRetryable: threadsFailure.isRetryable
        )
    }

    private static func title(for failure: ThreadsFailure) -> String {
        switch failure {
            case .notStarted: "This thread is not ready yet"
            case .roomUnavailable: "That conversation is gone"
            case .listUnavailable, .threadUnavailable: "Could not open this thread"
            case .paginationFailed: "Could not load older replies"
            case .subscriptionFailed: "Could not change what this thread notifies you about"
        }
    }
}
