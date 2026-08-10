//
//  PresenceServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Publishes the signed in user's presence and MSC4426 status to the homeserver.
///
/// There is nothing to observe here: the SDK exposes no listener for presence or status changes,
/// only these one-shot setters, so unlike the other Users services this one has no stream and no
/// subscription to release.
protocol PresenceServiceProtocol {

    /// Sets the signed in user's presence. `immediate` skips the debounce the SDK otherwise
    /// applies, which is worth doing right before the app goes to the background.
    func setPresence(_ presence: PresenceState, immediate: Bool) async throws

    /// Sets the signed in user's MSC4426 status.
    func setUserStatus(_ status: UserStatusInfo) async throws

    /// Clears the signed in user's MSC4426 status.
    func clearUserStatus() async throws

    /// Whether the homeserver understands the MSC4426 status field at all.
    func isUserStatusSupported() async throws -> Bool
}
