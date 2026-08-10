//
//  ChatViewModel.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Observation


/// Everything one conversation screen binds to: the rows, the composer, and what to say when an
/// action fails.
///
/// A thread screen uses this same view model over a thread focused timeline, because from here the
/// two are the same conversation with a different set of rows.
@Observable
final class ChatViewModel {

    /// Bound to the composer, as markdown.
    var composerText = ""

    /// The event the composer is replying to, nil for a plain message.
    var replyToEventID: String?

    /// The event the composer is editing, nil when it is composing a new message.
    ///
    /// Sending with this set turns into an edit, which is why the composer does not need a mode of
    /// its own to keep track of.
    var editingEntryID: EventIdentifier?

    /// The failure to present. Views clear it by setting it back to nil.
    var failure: UserFacingFailure?

    @ObservationIgnored
    private let repository: TimelineRepository

    init(repository: TimelineRepository) {
        self.repository = repository
    }

    /// The room this conversation belongs to.
    var roomID: String {
        repository.roomID
    }

    /// Every row to render, oldest first, date separators and read marker included.
    var entries: [TimelineEntry] {
        repository.entries
    }

    /// Whether the conversation is empty, so the screen can offer its "say something" state.
    var isEmpty: Bool {
        repository.isEmpty
    }

    /// Whether older events are on their way, for the spinner at the top of the list.
    var isPaginating: Bool {
        repository.paginationState.isPaginating
    }

    /// Whether scrolling further up is worth a request.
    var canPaginate: Bool {
        repository.paginationState.canPaginate
    }

    /// Whether the composer has something worth sending.
    var canSend: Bool {
        !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Whether this room's send queue is switched off after a failure, which is what justifies
    /// showing a "try again" banner rather than a per message retry.
    var isSendQueueWedged: Bool {
        repository.isSendQueueWedged
    }

    /// Upload progress of the attachments still going out, keyed by their media event.
    var uploadProgress: [String: Double] {
        repository.uploadProgress
    }

    /// Builds the conversation. Called when the screen appears for the first time.
    func start() async {
        await repository.start()
        await repository.fetchMembers()

        updateFailure()
    }

    /// Sends what is in the composer, as an edit when one is in progress, then clears it.
    ///
    /// The text is cleared before the send is awaited, the way every chat app does it: the local
    /// echo appears immediately, and a failure surfaces on that row rather than by refilling the
    /// composer under the user's fingers.
    func sendMessage() async {
        let markdown = composerText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !markdown.isEmpty else {
            return
        }

        let editedEntryID = editingEntryID
        let repliedToEventID = replyToEventID

        composerText = ""
        editingEntryID = nil
        replyToEventID = nil

        if let editedEntryID {
            await repository.edit(entryID: editedEntryID, markdown: markdown)
        } else {
            await repository.send(
                OutgoingMessage(
                    markdown      : markdown,
                    replyToEventID: repliedToEventID
                )
            )
        }

        updateFailure()
    }

    /// Asks for the previous page of events, for when the user reaches the top of the list.
    func loadMore() async {
        await repository.paginateBackwards()

        updateFailure()
    }

    /// Points the composer at an event, so the next message replies to it.
    func reply(to entry: TimelineEntry) {
        editingEntryID = nil
        replyToEventID = entry.eventIdentifier?.eventID
    }

    /// Loads one of the user's own messages back into the composer to be edited.
    func edit(_ entry: TimelineEntry) {
        guard let message = entry.message, message.isEditable else {
            return
        }

        replyToEventID = nil
        editingEntryID = message.eventIdentifier
        composerText = message.body
    }

    /// Abandons whatever the composer was replying to or editing, leaving the text alone.
    func cancelComposerContext() {
        replyToEventID = nil
        editingEntryID = nil
    }

    /// Deletes an event, or cancels it when it never left the send queue.
    func delete(_ entry: TimelineEntry) async {
        guard let entryID = entry.eventIdentifier else {
            return
        }

        await repository.redact(entryID: entryID)

        updateFailure()
    }

    /// Adds the reaction, or takes it back when the account already reacted with that key.
    func toggleReaction(
        entryID: EventIdentifier,
        key    : String
    ) async {

        await repository.toggleReaction(entryID: entryID, key: key)

        updateFailure()
    }

    /// Starts a poll in this room.
    ///
    /// Blank options are dropped rather than sent: a poll with an empty answer cannot be voted on
    /// in any client, so there is nothing useful to send.
    func createPoll(
        question     : String,
        answers      : [String],
        maxSelections: Int = 1,
        kind         : PollVisibility = .disclosed
    ) async {

        let options = answers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard
            !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            options.count >= Self.minimumPollAnswers
        else {
            return
        }

        await repository.createPoll(
            question     : question,
            answers      : options,
            maxSelections: max(1, maxSelections),
            kind         : kind
        )

        updateFailure()
    }

    /// Casts or replaces the account's vote. An empty selection retracts it.
    func vote(
        inPoll poll: PollEntry,
        answerIDs  : [String]
    ) async {

        guard
            let startEventID = poll.eventIdentifier.eventID,
            !poll.isEnded
        else {
            return
        }

        await repository.respondToPoll(startEventID: startEventID, answerIDs: answerIDs)

        updateFailure()
    }

    /// Closes a poll the account started.
    func endPoll(_ poll: PollEntry) async {
        guard
            let startEventID = poll.eventIdentifier.eventID,
            poll.isOwn,
            !poll.isEnded
        else {
            return
        }

        await repository.endPoll(
            startEventID: startEventID,
            text        : "The poll \"\(poll.question)\" has ended."
        )

        updateFailure()
    }

    /// Marks the conversation read up to its latest event, publicly.
    func markAsRead() async {
        await repository.markAsRead(.read)

        updateFailure()
    }

    /// Marks the conversation read up to one specific event, for when the user stops scrolling
    /// somewhere in the middle of the history.
    func markAsRead(upTo eventID: String) async {
        await repository.sendReadReceipt(.read, forEvent: eventID)

        updateFailure()
    }

    /// How far one member got in this conversation, for a read by list.
    func loadReceipt(ofUser userID: String) async -> ReceiptInfo? {
        let receipt = await repository.loadReceipt(.read, ofUser: userID)

        updateFailure()

        return receipt
    }

    /// Turns the send queue back on after a failure switched it off, which is what the banner's
    /// "try again" does.
    func retryFailedMessages() {
        repository.retrySendQueue()
    }

    /// Tears the conversation down when the screen goes away.
    func shutdown() {
        composerText = ""
        replyToEventID = nil
        editingEntryID = nil

        repository.shutdown()
    }

    private static let minimumPollAnswers = 2

    private func updateFailure() {
        guard let timelineFailure = repository.failure else {
            failure = nil

            return
        }

        failure = UserFacingFailure(
            title      : Self.title(for: timelineFailure),
            message    : timelineFailure.message,
            isRetryable: timelineFailure.isRetryable
        )
    }

    private static func title(for failure: TimelineFailure) -> String {
        switch failure {
            case .notStarted: "This conversation is not ready yet"
            case .roomUnavailable: "That conversation is gone"
            case .timelineUnavailable: "Could not open this conversation"
            case .sendFailed: "Your message did not go out"
            case .paginationFailed: "Could not load older messages"
            case .actionFailed: "Something went wrong"
            case .noActiveClient: "You are signed out"
        }
    }
}
