//
//  ThreadListServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// One room's threads: which ones exist, how that list changes, and how to ask for more of them.
///
/// An instance is bound to one room for its whole life, the same way a timeline is bound to one
/// focus, because that is how the SDK models it: the list hangs off the room object itself.
protocol ThreadListServiceProtocol {

    /// The room whose threads this lists.
    var roomID: String { get }

    /// Row changes, already resolved into domain entries and batched exactly as the SDK batched
    /// them, so one emission is one atomic UI update.
    ///
    /// The first batch is always a full reset with whatever is already loaded, which the SDK emits
    /// the moment the listener is attached. Nothing has been loaded at that point, which is why
    /// `start()` also fetches the opening page.
    var entryDiffs: AsyncStream<[CollectionDiff<ThreadEntry>]> { get }

    /// Whether a page of threads is in flight, and whether any are left to ask for.
    ///
    /// The state the SDK already holds is published as soon as `start()` runs: unlike the item
    /// listener, the pagination listener only reports transitions, so a subscriber would otherwise
    /// sit on a guess until something moved.
    var listStates: AsyncStream<ThreadListState> { get }

    /// Attaches to the room's thread list and fetches its opening page. Calling it again is a no op.
    func start() async throws

    /// Asks the homeserver for the next page of threads. Throws `ThreadsFailure.notStarted` before
    /// `start()` has run.
    ///
    /// The SDK ignores the call while a page is already loading, and once the end of the list has
    /// been reached, so nothing here has to defend against an over eager scroll view.
    func paginate() async throws

    /// Throws every loaded thread away and puts pagination back at the first page, leaving the
    /// listeners attached. A no op before `start()` has run.
    func reset() async

    /// Releases every listener this list owns. Called once, when the screen is closed.
    func shutdown()
}
