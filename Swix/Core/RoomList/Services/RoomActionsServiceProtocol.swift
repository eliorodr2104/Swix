//
//  RoomActionsServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Every write the chat list can perform on a single room, plus the recently visited history the
/// SDK keeps in account data.
protocol RoomActionsServiceProtocol {

    /// Pins or unpins a room, which is what moves it in and out of the Pinned section.
    func setFavourite(
        _ isFavourite: Bool,
        roomID       : String
    ) async throws

    /// Pushes a room down or brings it back into the main section.
    func setLowPriority(
        _ isLowPriority: Bool,
        roomID         : String
    ) async throws

    /// Sends a read receipt for the room's latest event, clearing its unread counters.
    func markAsRead(roomID: String) async throws

    /// Sets or clears the manual unread flag, independently of the counters.
    func setUnreadFlag(
        _ isUnread: Bool,
        roomID    : String
    ) async throws

    /// Leaves a room. The list drops it on the next diff because every filter excludes left rooms.
    func leave(roomID: String) async throws

    /// Records that the user opened a room, for the recently visited list.
    func trackRecentlyVisited(roomID: String) async throws

    /// The rooms the user opened most recently, newest first, as the server stored them.
    func recentlyVisitedRoomIDs() async throws -> [String]
}
