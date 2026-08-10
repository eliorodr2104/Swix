//
//  RoomListLoadState.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// How far along the room list is in producing its first usable page.
///
/// The total is optional even once loaded, because a homeserver is allowed to answer a sliding
/// sync request without ever telling the client how many rooms exist in total.
enum RoomListLoadState: Equatable {

    /// Nothing has arrived yet, so the chat list should show its loading state.
    case notLoaded

    /// The list is usable, carrying the total number of rooms when the server disclosed it.
    case loaded(totalRoomCount: Int?)

    /// Whether the list has anything worth rendering.
    var isLoaded: Bool {
        switch self {
            case .notLoaded: false
            case .loaded: true
        }
    }

    /// How many rooms the account has in total, when the server said so.
    var totalRoomCount: Int? {
        switch self {
            case .notLoaded: nil
            case .loaded(let totalRoomCount): totalRoomCount
        }
    }
}
