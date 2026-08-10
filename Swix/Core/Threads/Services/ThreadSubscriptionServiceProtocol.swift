//
//  ThreadSubscriptionServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Reads and writes whether the account follows a thread (MSC4306).
///
/// Subscriptions hang off the room rather than off the thread list, one request per thread, which is
/// why they are a service of their own instead of another column of the list. One instance serves
/// every room: there is no per room state to hold on to.
protocol ThreadSubscriptionServiceProtocol {

    /// Asks the homeserver whether the account follows one thread. Never answers `.unknown`: the
    /// request either settles the question or throws.
    func loadSubscription(
        roomID     : String,
        rootEventID: String
    ) async throws -> ThreadSubscriptionState

    /// Starts or stops following a thread.
    func setSubscription(
        _ isSubscribed: Bool,
        roomID        : String,
        rootEventID   : String
    ) async throws
}
