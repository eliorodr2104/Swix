//
//  TimelineProviderProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Hands out the timelines of a session and keeps them alive while they are in use.
///
/// A timeline is expensive to build and refills from scratch every time, so the same one is reused
/// for as long as a room stays open. This is also the only entry point the Threads feature needs:
/// a thread is an ordinary timeline focused on its root event.
protocol TimelineProviderProtocol {

    /// The room's main conversation, built on first call and reused afterwards.
    ///
    /// The returned service has already been started, so the caller can subscribe to its streams
    /// and will still receive the initial reset that was buffered while it was setting up.
    func liveTimeline(forRoom roomID: String) async throws -> any TimelineServiceProtocol

    /// One thread's conversation, keyed by its root event so several threads of the same room can
    /// be open at once.
    func makeThreadTimeline(
        roomID     : String,
        rootEventID: String
    ) async throws -> any TimelineServiceProtocol

    /// Clears the unread state of every room the account is in, in one request.
    func markAllRoomsAsRead() async throws

    /// Releases the conversation and every thread of one room, for when the user leaves the screen.
    func release(roomID: String)

    /// Releases every timeline this provider ever built. Called once, when the session ends.
    func shutdown()
}
