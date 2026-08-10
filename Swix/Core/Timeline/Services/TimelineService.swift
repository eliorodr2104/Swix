//
//  TimelineService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import MatrixRustSDK
import os


/// The default `TimelineServiceProtocol`, built on `Room.timelineWithConfiguration`.
final class TimelineService: TimelineServiceProtocol {

    let roomID: String

    let entryDiffs: AsyncStream<[CollectionDiff<TimelineEntry>]>

    let paginationStates: AsyncStream<PaginationState>

    let sendQueueEvents: AsyncStream<SendQueueEvent>

    private let focus: TimelineFocus

    private let clientService: any ClientServiceProtocol

    private let roomProvider: any RoomProviding

    private let paginationPageSize: UInt16

    private let diffContinuation: AsyncStream<[CollectionDiff<TimelineEntry>]>.Continuation

    private let paginationContinuation: AsyncStream<PaginationState>.Continuation

    private let sendQueueContinuation: AsyncStream<SendQueueEvent>.Continuation

    private let subscriptions = SubscriptionBag()

    // The Timeline object is kept for as long as the room stays open: it is what the item listener
    // was registered on, and asking the room for another one would hand back an empty list that
    // only refills on the next live event.
    private var timeline: Timeline?

    private var room: Room?

    // The listeners are Rust's only route back into this process. The TaskHandles in the bag keep
    // the subscriptions alive, these keep the adapters that feed the streams alive.
    private var entriesListener: SDKListener<[TimelineDiff]>?

    private var paginationListener: SDKListener<PaginationStatus>?

    private var sendQueueListener: SDKListener<RoomSendQueueUpdate>?

    init(
        roomID            : String,
        focus             : TimelineFocus,
        clientService     : any ClientServiceProtocol,
        roomProvider      : any RoomProviding,
        paginationPageSize: UInt16 = MatrixConfiguration.timelinePaginationPageSize
    ) {
        self.roomID             = roomID
        self.focus              = focus
        self.clientService      = clientService
        self.roomProvider       = roomProvider
        self.paginationPageSize = paginationPageSize

        (entryDiffs, diffContinuation) = AsyncStream<[CollectionDiff<TimelineEntry>]>.makeStream(bufferingPolicy: .unbounded)
        (paginationStates, paginationContinuation) = AsyncStream<PaginationState>.makeStream(bufferingPolicy: .unbounded)
        (sendQueueEvents, sendQueueContinuation) = AsyncStream<SendQueueEvent>.makeStream(bufferingPolicy: .unbounded)
    }

    func start() async throws {
        guard timeline == nil else {
            return
        }

        let room = try activeRoom()

        do {
            let timeline = try await room.timelineWithConfiguration(configuration: makeConfiguration())

            self.room = room
            self.timeline = timeline

            await observeEntries(of: timeline)
            await observePagination(of: timeline)
            await observeSendQueue(of: room)

            Log.timeline.notice("Timeline attached to room \(self.roomID, privacy: .public)")

        } catch { throw TimelineFailure.timelineUnavailable(SDKErrorInfo(error)) }
    }

    func paginateBackwards() async throws -> Bool {
        let timeline = try await activeTimeline()

        do {
            return try await timeline.paginateBackwards(numEvents: paginationPageSize)

        } catch { throw TimelineFailure.paginationFailed(SDKErrorInfo(error)) }
    }

    func send(_ message: OutgoingMessage) async throws {
        let timeline = try await activeTimeline()
        let content = messageEventContentFromMarkdown(md: message.markdown)

        do {
            guard let replyToEventID = message.replyToEventID else {
                _ = try await timeline.send(msg: content)

                return
            }

            try await timeline.sendReply(msg: content, eventId: replyToEventID)

        } catch { throw TimelineFailure.sendFailed(SDKErrorInfo(error)) }
    }

    func sendLocation(
        body       : String,
        geoUri     : String,
        description: String?,
        zoomLevel  : UInt8?
    ) async throws {

        let timeline = try await activeTimeline()

        do {
            try await timeline.sendLocation(
                body            : body,
                geoUri          : geoUri,
                description     : description,
                zoomLevel       : zoomLevel,
                assetType       : .sender,
                repliedToEventId: nil
            )

        } catch { throw TimelineFailure.sendFailed(SDKErrorInfo(error)) }
    }

    func edit(
        entryID : EventIdentifier,
        markdown: String
    ) async throws {

        let timeline = try await activeTimeline()
        let content = messageEventContentFromMarkdown(md: markdown)

        do {
            try await timeline.edit(
                eventOrTransactionId: TimelineEntryMapper.makeItemID(from: entryID),
                newContent          : .roomMessage(content: content)
            )

        } catch { throw TimelineFailure.actionFailed(SDKErrorInfo(error)) }
    }

    func redact(
        entryID: EventIdentifier,
        reason : String?
    ) async throws {

        let timeline = try await activeTimeline()

        do {
            try await timeline.redactEvent(
                eventOrTransactionId: TimelineEntryMapper.makeItemID(from: entryID),
                reason              : reason
            )

        } catch { throw TimelineFailure.actionFailed(SDKErrorInfo(error)) }
    }

    @discardableResult
    func toggleReaction(
        entryID: EventIdentifier,
        key    : String
    ) async throws -> Bool {

        let timeline = try await activeTimeline()

        do {
            return try await timeline.toggleReaction(
                itemId: TimelineEntryMapper.makeItemID(from: entryID),
                key   : key
            )

        } catch { throw TimelineFailure.actionFailed(SDKErrorInfo(error)) }
    }

    func createPoll(
        question     : String,
        answers      : [String],
        maxSelections: Int,
        kind         : PollVisibility
    ) async throws {

        let timeline = try await activeTimeline()

        do {
            try await timeline.createPoll(
                question     : question,
                answers      : answers,
                maxSelections: UInt8(clamping: maxSelections),
                pollKind     : Self.makePollKind(from: kind)
            )

        } catch { throw TimelineFailure.sendFailed(SDKErrorInfo(error)) }
    }

    func respondToPoll(
        startEventID: String,
        answerIDs   : [String]
    ) async throws {

        let timeline = try await activeTimeline()

        do {
            try await timeline.sendPollResponse(
                pollStartEventId: startEventID,
                answers         : answerIDs
            )

        } catch { throw TimelineFailure.sendFailed(SDKErrorInfo(error)) }
    }

    func endPoll(
        startEventID: String,
        text        : String
    ) async throws {

        let timeline = try await activeTimeline()

        do {
            try await timeline.endPoll(
                pollStartEventId: startEventID,
                text            : text
            )

        } catch { throw TimelineFailure.actionFailed(SDKErrorInfo(error)) }
    }

    func markAsRead(_ kind: ReceiptKind) async throws {
        let timeline = try await activeTimeline()

        do {
            try await timeline.markAsRead(receiptType: Self.makeReceiptType(from: kind))

        } catch { throw TimelineFailure.actionFailed(SDKErrorInfo(error)) }
    }

    func sendReadReceipt(
        _ kind          : ReceiptKind,
        forEvent eventID: String
    ) async throws {

        let timeline = try await activeTimeline()

        do {
            try await timeline.sendReadReceipt(
                receiptType: Self.makeReceiptType(from: kind),
                eventId    : eventID
            )

        } catch { throw TimelineFailure.actionFailed(SDKErrorInfo(error)) }
    }

    func loadReceipt(
        _ kind       : ReceiptKind,
        ofUser userID: String
    ) async throws -> ReceiptInfo? {

        try await start()

        guard let room else {
            throw TimelineFailure.notStarted
        }

        do {
            let receipt = try await room.loadUserReceipt(
                receiptType: Self.makeReceiptType(from: kind),
                thread     : receiptThread,
                userId     : userID
            )

            guard let receipt else {
                return nil
            }

            return ReceiptInfo(
                userID   : userID,
                eventID  : receipt.eventId,
                timestamp: receipt.receipt.timestamp.map { TimelineEntryMapper.makeDate(from: $0) }
            )

        } catch { throw TimelineFailure.actionFailed(SDKErrorInfo(error)) }
    }

    func latestEventID() async -> String? {
        guard let timeline = try? await activeTimeline() else {
            return nil
        }

        return await timeline.latestEventId()
    }

    func fetchMembers() async {
        guard let timeline = try? await activeTimeline() else {
            return
        }

        await timeline.fetchMembers()
    }

    func retryDecryption(sessionIDs: [String]) {
        timeline?.retryDecryption(sessionIds: sessionIDs)
    }

    func enableSendQueue(_ isEnabled: Bool) {
        room?.enableSendQueue(enable: isEnabled)
    }

    func shutdown() {
        subscriptions.cancelAll()

        entriesListener = nil
        paginationListener = nil
        sendQueueListener = nil
        timeline = nil
        room = nil
    }

    /// Read receipts have to be tracked explicitly, and the SDK warns the cost is real, so this
    /// asks for message like events only: nobody needs to know who read a topic change.
    private func makeConfiguration() -> TimelineConfiguration {
        TimelineConfiguration(
            focus            : focus,
            filter           : .all,
            internalIdPrefix : nil,
            dateDividerMode  : .daily,
            trackReadReceipts: .messageLikeEvents,
            reportUtds       : true
        )
    }

    /// Which thread a receipt applies to follows the timeline's own focus: a receipt sent from
    /// inside a thread must not move the main conversation's marker.
    private var receiptThread: ReceiptThread {
        switch focus {
            case .thread(let rootEventID): .thread(threadRootEventId: rootEventID)
            case .live, .event, .pinnedEvents: .main
        }
    }

    /// Attaching lazily here means a screen can act on an event without having had to start the
    /// service first, which is what keeps every operation on this type a single call.
    private func activeTimeline() async throws -> Timeline {
        try await start()

        guard let timeline else {
            throw TimelineFailure.notStarted
        }

        return timeline
    }

    /// `RoomProviding` fails with our own `SyncFailure` only when sync never ran, which is worth
    /// telling apart from a room the list genuinely does not have.
    private func activeRoom() throws -> Room {
        do {
            return try roomProvider.room(withId: roomID)

        } catch is SyncFailure {
            throw TimelineFailure.notStarted

        } catch { throw TimelineFailure.roomUnavailable(SDKErrorInfo(error)) }
    }

    private func observeEntries(of timeline: Timeline) async {
        let (updates, listener) = makeSDKStream(of: [TimelineDiff].self)

        // The account cannot change while a timeline is open, so the id is read once here rather
        // than on every diff: it decides which reactions and votes count as the user's own.
        let ownUserID = clientService.userID

        entriesListener = listener

        subscriptions.retain(await timeline.addListener(listener: listener))
        subscriptions.retain(
            Task { [diffContinuation, ownUserID] in
                for await batch in updates {
                    diffContinuation.yield(
                        TimelineDiffMapper.makeDiffs(from: batch, ownUserID: ownUserID)
                    )
                }
            }
        )
    }

    private func observePagination(of timeline: Timeline) async {
        let (statuses, listener) = makeSDKStream(of: PaginationStatus.self)

        do {
            let handle = try await timeline.subscribeToBackPaginationStatus(listener: listener)

            paginationListener = listener

            subscriptions.retain(handle)
            subscriptions.retain(
                Task { [paginationContinuation] in
                    for await status in statuses {
                        paginationContinuation.yield(
                            TimelineDiffMapper.makePaginationState(from: status)
                        )
                    }
                }
            )
        } catch {
            Log.timeline.error("Could not observe back pagination: \(String(reflecting: error), privacy: .public)")
        }
    }

    private func observeSendQueue(of room: Room) async {
        let (updates, listener) = makeSDKStream(of: RoomSendQueueUpdate.self)

        do {
            let handle = try await room.subscribeToSendQueueUpdates(listener: listener)

            sendQueueListener = listener

            subscriptions.retain(handle)
            subscriptions.retain(
                Task { [sendQueueContinuation] in
                    for await update in updates {
                        sendQueueContinuation.yield(SendQueueUpdateMapper.makeEvent(from: update))
                    }
                }
            )
        } catch {
            Log.timeline.error("Could not observe the send queue: \(String(reflecting: error), privacy: .public)")
        }
    }

    private static func makePollKind(from visibility: PollVisibility) -> PollKind {
        switch visibility {
            case .disclosed: .disclosed
            case .undisclosed: .undisclosed
        }
    }

    private static func makeReceiptType(from kind: ReceiptKind) -> ReceiptType {
        switch kind {
            case .read: .read
            case .readPrivate: .readPrivate
            case .fullyRead: .fullyRead
        }
    }
}
