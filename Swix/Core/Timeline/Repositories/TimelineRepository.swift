//
//  TimelineRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation
import os


/// The single source of truth for one open conversation, and the only writer of `entries`.
///
/// The array is rebuilt exclusively by applying the service's diff batches in order, never by
/// refetching, so the rows stay in exactly the order the SDK put them in. Send queue updates arrive
/// separately and only ever rewrite one row's state, which is why they cannot disturb that order.
@Observable
final class TimelineRepository {

    /// Every row of the conversation, oldest first, layout rows included.
    private(set) var entries: [TimelineEntry] = []

    /// Whether older events are being fetched, and whether any are left.
    private(set) var paginationState: PaginationState = .idle(hasReachedStart: false)

    /// Whether a recoverable failure switched this room's send queue off, so nothing else will go
    /// out until `retrySendQueue()` turns it back on.
    private(set) var isSendQueueWedged = false

    /// Upload progress of the attachments still on their way out, keyed by their media event, from
    /// zero to one. An entry disappears once the queue stops reporting on it.
    private(set) var uploadProgress: [String: Double] = [:]

    /// The last failure, kept until the next attempt clears it.
    private(set) var failure: TimelineFailure?

    @ObservationIgnored
    private let service: any TimelineServiceProtocol

    @ObservationIgnored
    private let subscriptions = SubscriptionBag()

    @ObservationIgnored
    private var isObserving = false

    init(service: any TimelineServiceProtocol) {
        self.service = service
    }

    /// The room this conversation belongs to.
    var roomID: String {
        service.roomID
    }

    /// The messages and polls alone, for the places that do not care about layout rows.
    var events: [TimelineEntry] {
        entries.filter { $0.eventIdentifier != nil }
    }

    /// Whether the conversation has nothing to show at all.
    var isEmpty: Bool {
        events.isEmpty
    }

    /// Starts observing the timeline service on first call, then attaches it.
    func start() async {
        observeServiceIfNeeded()

        await run {
            try await service.start()
        }
    }

    /// Asks for the previous page of events, for when the user scrolls to the top.
    ///
    /// Nothing happens while a page is already in flight or once the start of the room is loaded:
    /// the SDK would no op anyway, and this way the spinner does not flicker.
    func paginateBackwards() async {
        guard paginationState.canPaginate else {
            return
        }

        await run {
            _ = try await service.paginateBackwards()
        }
    }

    /// Queues a message. The local echo shows up as an ordinary diff moments later.
    func send(_ message: OutgoingMessage) async {
        guard !message.isEmpty else {
            return
        }

        await run {
            try await service.send(message)
        }
    }

    /// Replaces the body of a message the user already sent.
    func edit(
        entryID : EventIdentifier,
        markdown: String
    ) async {

        await run {
            try await service.edit(entryID: entryID, markdown: markdown)
        }
    }

    /// Deletes a message, or cancels it when it never left the queue.
    func redact(
        entryID: EventIdentifier,
        reason : String? = nil
    ) async {

        await run {
            try await service.redact(entryID: entryID, reason: reason)
        }
    }

    /// Adds or takes back one reaction on an event.
    func toggleReaction(
        entryID: EventIdentifier,
        key    : String
    ) async {

        await run {
            try await service.toggleReaction(entryID: entryID, key: key)
        }
    }

    /// Starts a poll in this room.
    func createPoll(
        question     : String,
        answers      : [String],
        maxSelections: Int,
        kind         : PollVisibility
    ) async {

        await run {
            try await service.createPoll(
                question     : question,
                answers      : answers,
                maxSelections: maxSelections,
                kind         : kind
            )
        }
    }

    /// Casts or replaces the account's vote in a poll.
    func respondToPoll(
        startEventID: String,
        answerIDs   : [String]
    ) async {

        await run {
            try await service.respondToPoll(startEventID: startEventID, answerIDs: answerIDs)
        }
    }

    /// Closes a poll, with the fallback text clients without poll support will show.
    func endPoll(
        startEventID: String,
        text        : String
    ) async {

        await run {
            try await service.endPoll(startEventID: startEventID, text: text)
        }
    }

    /// Moves a marker to the latest event of this conversation.
    func markAsRead(_ kind: ReceiptKind) async {
        await run {
            try await service.markAsRead(kind)
        }
    }

    /// Moves a marker to one specific event.
    func sendReadReceipt(
        _ kind          : ReceiptKind,
        forEvent eventID: String
    ) async {

        await run {
            try await service.sendReadReceipt(kind, forEvent: eventID)
        }
    }

    /// Reads how far one user got in this room, nil when they never sent a receipt.
    ///
    /// This one hands the value back instead of publishing it, because it answers a question about
    /// somebody else rather than describing the state of the conversation.
    func loadReceipt(
        _ kind       : ReceiptKind,
        ofUser userID: String
    ) async -> ReceiptInfo? {

        do {
            let receipt = try await service.loadReceipt(kind, ofUser: userID)

            failure = nil

            return receipt
        } catch {
            store(TimelineFailure.wrapping(error))

            return nil
        }
    }

    /// Turns the room's send queue back on after a recoverable failure switched it off.
    func retrySendQueue() {
        service.enableSendQueue(true)

        isSendQueueWedged = false
    }

    /// Asks the SDK to decrypt again what it could not, after new room keys arrived.
    func retryDecryption(sessionIDs: [String]) {
        service.retryDecryption(sessionIDs: sessionIDs)
    }

    /// Resolves member profiles so display names replace raw user ids.
    func fetchMembers() async {
        await service.fetchMembers()
    }

    /// Releases every subscription this repository and its service own. Called once, by whoever
    /// created them, when the conversation is closed.
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
                    self?.entries.applyDiffs(batch)
                }
            }
        )

        subscriptions.retain(
            Task { [weak self, states = service.paginationStates] in
                for await state in states {
                    self?.paginationState = state
                }
            }
        )

        subscriptions.retain(
            Task { [weak self, events = service.sendQueueEvents] in
                for await event in events {
                    self?.apply(event)
                }
            }
        )
    }

    /// A send queue update never changes the shape of the list, only the state of the one row whose
    /// transaction it names, so the array is edited in place rather than rebuilt.
    private func apply(_ event: SendQueueEvent) {
        switch event {
            case .failed(_, _, let isRecoverable):
                isSendQueueWedged = isRecoverable

            case .retrying, .sent:
                isSendQueueWedged = false

            case .uploadProgress(let relatedTo, let fraction):
                uploadProgress[relatedTo] = fraction

            case .queued, .cancelled, .replaced:
                break
        }

        guard
            let transactionID = event.transactionID,
            let sendState = event.sendState
        else {
            return
        }

        for index in entries.indices where entries[index].eventIdentifier?.transactionID == transactionID {
            entries[index].updateSendState(sendState)
        }
    }

    private func run(_ action: () async throws -> Void) async {
        do {
            try await action()

            failure = nil
        } catch {
            store(TimelineFailure.wrapping(error))
        }
    }

    private func store(_ timelineFailure: TimelineFailure) {
        Log.timeline.error("Timeline failure: \(timelineFailure.message, privacy: .public)")

        failure = timelineFailure
    }
}
