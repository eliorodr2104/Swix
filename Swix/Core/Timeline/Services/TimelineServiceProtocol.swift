//
//  TimelineServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// One room's conversation: the rows, how they change, and everything the user can do to them.
///
/// An instance is bound to one focus for its whole life, the room's live timeline or a single
/// thread, because that is how the SDK models it: switching focus means a different timeline, not a
/// different call on this one.
protocol TimelineServiceProtocol {

    /// The room this timeline belongs to.
    var roomID: String { get }

    /// Row changes, already resolved into domain entries and batched exactly as the SDK batched
    /// them, so one emission is one atomic UI update.
    ///
    /// The first batch is always a full reset with whatever is already cached, which the SDK emits
    /// the moment the listener is attached.
    var entryDiffs: AsyncStream<[CollectionDiff<TimelineEntry>]> { get }

    /// Whether older events are being fetched, and whether any are left to fetch.
    var paginationStates: AsyncStream<PaginationState> { get }

    /// What the room's send queue did to the messages the user sent, keyed by transaction id.
    var sendQueueEvents: AsyncStream<SendQueueEvent> { get }

    /// Builds the SDK timeline and starts emitting. Calling it again is a no op.
    func start() async throws

    /// Asks the homeserver for the previous page of events, returning whether the start of the
    /// room's history has now been reached.
    func paginateBackwards() async throws -> Bool

    /// Queues a message for sending. Returning does not mean it was sent, only that the queue took
    /// it: the rest of the story arrives through `sendQueueEvents`.
    func send(_ message: OutgoingMessage) async throws

    /// Sends a one-shot location message: the sender's position at the moment of sending, not a
    /// live share.
    ///
    /// This exists on the timeline, rather than as a second timeline the Location feature would
    /// have to keep of its own, so a location message rides the same send queue and shows up
    /// through the same `entryDiffs` every other message does.
    func sendLocation(
        body       : String,
        geoUri     : String,
        description: String?,
        zoomLevel  : UInt8?
    ) async throws

    /// Replaces the body of an event, whether it is already on the homeserver or still queued.
    func edit(
        entryID : EventIdentifier,
        markdown: String
    ) async throws

    /// Deletes an event, cancelling it instead when it never left the queue.
    func redact(
        entryID: EventIdentifier,
        reason : String?
    ) async throws

    /// Adds the reaction, or takes it back when the account already reacted with that key.
    /// Returns whether the reaction is now on the event.
    @discardableResult
    func toggleReaction(
        entryID: EventIdentifier,
        key    : String
    ) async throws -> Bool

    /// Starts a poll in this room.
    func createPoll(
        question     : String,
        answers      : [String],
        maxSelections: Int,
        kind         : PollVisibility
    ) async throws

    /// Casts the account's vote, replacing any previous one. An empty selection retracts the vote.
    func respondToPoll(
        startEventID: String,
        answerIDs   : [String]
    ) async throws

    /// Closes a poll, so late votes stop counting and the tally becomes final.
    ///
    /// `text` is the fallback body clients without poll support will show instead.
    func endPoll(
        startEventID: String,
        text        : String
    ) async throws

    /// Moves the requested marker to the latest event this timeline can see.
    func markAsRead(_ kind: ReceiptKind) async throws

    /// Moves the requested marker to one specific event, for when the user scrolls back up and
    /// stops somewhere in the middle.
    func sendReadReceipt(
        _ kind          : ReceiptKind,
        forEvent eventID: String
    ) async throws

    /// Reads one user's receipt out of the local store, which is how far that user got in this
    /// room. Nil when they never sent one.
    func loadReceipt(
        _ kind       : ReceiptKind,
        ofUser userID: String
    ) async throws -> ReceiptInfo?

    /// The most recent event this timeline knows about, for marking a room read without opening it.
    func latestEventID() async -> String?

    /// Resolves the room's member profiles, so display names replace raw user ids.
    func fetchMembers() async

    /// Asks the SDK to have another go at events it could not decrypt, after new keys arrived.
    func retryDecryption(sessionIDs: [String])

    /// Turns this room's send queue back on after a recoverable failure switched it off.
    ///
    /// The SDK deliberately leaves it off, since retrying into a dead connection would only wedge
    /// the next message too, so somebody has to say when it is worth trying again.
    func enableSendQueue(_ isEnabled: Bool)

    /// Releases every listener this timeline owns. Called once, when the room is closed.
    func shutdown()
}
