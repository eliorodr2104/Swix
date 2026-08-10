//
//  NotificationItemServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Resolves notifications: given a room and an event, fetches, decrypts and flattens it into
/// something a notification can display.
///
/// This is the piece a Notification Service Extension adopts verbatim. In the extension there is no
/// sync loop, so no `NotificationSyncServiceProviding` is passed and the client is built with the
/// cross process setup, which takes the store lock the main app also honours.
protocol NotificationItemServiceProtocol {

    /// Notifications the running sync loop produced, for in app banners. Empty until
    /// `startObservingSyncNotifications()` has been called.
    var syncNotifications: AsyncStream<NotificationItem> { get }

    /// Starts forwarding the notifications sync raises into `syncNotifications`.
    func startObservingSyncNotifications() async throws

    /// Fetches one notification. Nil means the event exists but must not be shown, because the push
    /// rules filtered it out, because it was redacted, or because the server could not find it.
    func notification(
        roomID : String,
        eventID: String
    ) async throws -> NotificationItem?

    /// Fetches several notifications in one round trip, keyed by event ID. Events that must not be
    /// shown, and events the homeserver failed on, are simply absent from the result.
    func notifications(eventIDsByRoomID: [String: [String]]) async throws -> [String: NotificationItem]

    /// Releases the notification client and the sync bridge. Called once, when the session ends.
    func shutdown()
}
