//
//  MockTimelineService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

@testable import Swix


/// A `TimelineServiceProtocol` double that records every call it received and lets a test push
/// entry diffs, pagination states and send queue events through its three streams on demand.
final class MockTimelineService: TimelineServiceProtocol {

    let roomID: String

    let entryDiffs: AsyncStream<[CollectionDiff<TimelineEntry>]>

    let paginationStates: AsyncStream<PaginationState>

    let sendQueueEvents: AsyncStream<SendQueueEvent>

    /// How many times `start()` was called.
    private(set) var startCallCount = 0

    /// How many times `paginateBackwards()` was called.
    private(set) var paginateBackwardsCallCount = 0

    /// Every message `send(_:)` was called with, oldest first.
    private(set) var sentMessages: [OutgoingMessage] = []

    /// Every `(entryID, markdown)` pair `edit` was called with, oldest first.
    private(set) var edits: [(entryID: EventIdentifier, markdown: String)] = []

    /// Every `(entryID, reason)` pair `redact` was called with, oldest first.
    private(set) var redactions: [(entryID: EventIdentifier, reason: String?)] = []

    /// Every `(entryID, key)` pair `toggleReaction` was called with, oldest first.
    private(set) var toggledReactions: [(entryID: EventIdentifier, key: String)] = []

    /// Every poll `createPoll` was called with, oldest first.
    private(set) var createdPolls: [(
        question     : String,
        answers      : [String],
        maxSelections: Int,
        kind         : PollVisibility
    )] = []

    /// Every `(startEventID, answerIDs)` pair `respondToPoll` was called with, oldest first.
    private(set) var pollResponses: [(startEventID: String, answerIDs: [String])] = []

    /// Every `(startEventID, text)` pair `endPoll` was called with, oldest first.
    private(set) var endedPolls: [(startEventID: String, text: String)] = []

    /// Every marker `markAsRead` was called with, oldest first.
    private(set) var readMarks: [ReceiptKind] = []

    /// Every `(kind, eventID)` pair `sendReadReceipt` was called with, oldest first.
    private(set) var readReceiptsSent: [(kind: ReceiptKind, eventID: String)] = []

    /// Every value `enableSendQueue` was called with, oldest first.
    private(set) var enableSendQueueCalls: [Bool] = []

    /// Every session id list `retryDecryption` was called with, oldest first.
    private(set) var retryDecryptionCalls: [[String]] = []

    /// How many times `fetchMembers()` was called.
    private(set) var fetchMembersCallCount = 0

    /// How many times `shutdown()` was called.
    private(set) var shutdownCallCount = 0

    /// What `start()` throws next time it is called, nil for a plain success.
    var startError: (any Error)?

    /// What `paginateBackwards()` returns or throws.
    var paginateBackwardsResult: Result<Bool, any Error> = .success(false)

    /// What `send(_:)` throws once set, nil for a plain success.
    var sendError: (any Error)?

    /// What `edit` throws once set, nil for a plain success.
    var editError: (any Error)?

    /// What `redact` throws once set, nil for a plain success.
    var redactError: (any Error)?

    /// What `toggleReaction` returns or throws.
    var toggleReactionResult: Result<Bool, any Error> = .success(true)

    /// What `createPoll` throws once set, nil for a plain success.
    var createPollError: (any Error)?

    /// What `respondToPoll` throws once set, nil for a plain success.
    var respondToPollError: (any Error)?

    /// What `endPoll` throws once set, nil for a plain success.
    var endPollError: (any Error)?

    /// What `markAsRead` throws once set, nil for a plain success.
    var markAsReadError: (any Error)?

    /// What `sendReadReceipt` throws once set, nil for a plain success.
    var sendReadReceiptError: (any Error)?

    /// What `loadReceipt` returns or throws.
    var loadReceiptResult: Result<ReceiptInfo?, any Error> = .success(nil)

    /// What `latestEventID()` returns.
    var latestEventIDResult: String?

    private let entryDiffContinuation: AsyncStream<[CollectionDiff<TimelineEntry>]>.Continuation

    private let paginationStateContinuation: AsyncStream<PaginationState>.Continuation

    private let sendQueueEventContinuation: AsyncStream<SendQueueEvent>.Continuation

    init(roomID: String = "!room:example.org") {
        self.roomID = roomID

        (entryDiffs, entryDiffContinuation) = AsyncStream<[CollectionDiff<TimelineEntry>]>.makeStream(bufferingPolicy: .unbounded)
        (paginationStates, paginationStateContinuation) = AsyncStream<PaginationState>.makeStream(bufferingPolicy: .unbounded)
        (sendQueueEvents, sendQueueEventContinuation) = AsyncStream<SendQueueEvent>.makeStream(bufferingPolicy: .unbounded)
    }

    func start() async throws {
        startCallCount += 1

        if let startError {
            throw startError
        }
    }

    func paginateBackwards() async throws -> Bool {
        paginateBackwardsCallCount += 1

        return try paginateBackwardsResult.get()
    }

    func send(_ message: OutgoingMessage) async throws {
        sentMessages.append(message)

        if let sendError {
            throw sendError
        }
    }

    func sendLocation(
        body       : String,
        geoUri     : String,
        description: String?,
        zoomLevel  : UInt8?
    ) async throws {

        // Not exercised by these suites: no feature under test sends a location.
    }

    func edit(
        entryID : EventIdentifier,
        markdown: String
    ) async throws {

        edits.append((entryID, markdown))

        if let editError {
            throw editError
        }
    }

    func redact(
        entryID: EventIdentifier,
        reason : String?
    ) async throws {

        redactions.append((entryID, reason))

        if let redactError {
            throw redactError
        }
    }

    @discardableResult
    func toggleReaction(
        entryID: EventIdentifier,
        key    : String
    ) async throws -> Bool {

        toggledReactions.append((entryID, key))

        return try toggleReactionResult.get()
    }

    func createPoll(
        question     : String,
        answers      : [String],
        maxSelections: Int,
        kind         : PollVisibility
    ) async throws {

        createdPolls.append((question, answers, maxSelections, kind))

        if let createPollError {
            throw createPollError
        }
    }

    func respondToPoll(
        startEventID: String,
        answerIDs   : [String]
    ) async throws {

        pollResponses.append((startEventID, answerIDs))

        if let respondToPollError {
            throw respondToPollError
        }
    }

    func endPoll(
        startEventID: String,
        text        : String
    ) async throws {

        endedPolls.append((startEventID, text))

        if let endPollError {
            throw endPollError
        }
    }

    func markAsRead(_ kind: ReceiptKind) async throws {
        readMarks.append(kind)

        if let markAsReadError {
            throw markAsReadError
        }
    }

    func sendReadReceipt(
        _ kind          : ReceiptKind,
        forEvent eventID: String
    ) async throws {

        readReceiptsSent.append((kind, eventID))

        if let sendReadReceiptError {
            throw sendReadReceiptError
        }
    }

    func loadReceipt(
        _ kind       : ReceiptKind,
        ofUser userID: String
    ) async throws -> ReceiptInfo? {

        try loadReceiptResult.get()
    }

    func latestEventID() async -> String? {
        latestEventIDResult
    }

    func fetchMembers() async {
        fetchMembersCallCount += 1
    }

    func retryDecryption(sessionIDs: [String]) {
        retryDecryptionCalls.append(sessionIDs)
    }

    func enableSendQueue(_ isEnabled: Bool) {
        enableSendQueueCalls.append(isEnabled)
    }

    func shutdown() {
        shutdownCallCount += 1
    }

    /// Pushes one diff batch to whoever is observing `entryDiffs`.
    func emit(diffs: [CollectionDiff<TimelineEntry>]) {
        entryDiffContinuation.yield(diffs)
    }

    /// Pushes one pagination state to whoever is observing `paginationStates`.
    func emit(paginationState: PaginationState) {
        paginationStateContinuation.yield(paginationState)
    }

    /// Pushes one send queue event to whoever is observing `sendQueueEvents`.
    func emit(sendQueueEvent: SendQueueEvent) {
        sendQueueEventContinuation.yield(sendQueueEvent)
    }
}
