//
//  RoomListFilter.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Which rooms the chat list is currently asking for.
///
/// Every case is applied on top of "rooms the user has not left", so switching filters never
/// resurrects an abandoned room.
enum RoomListFilter: Equatable {

    /// Everything the account is still a member of.
    case all

    /// Only the rooms the user pinned.
    case favourites

    /// Only the rooms with something new in them.
    case unread

    /// Only one to one chats.
    case people

    /// Only group rooms.
    case groups

    /// Rooms whose name matches what the user typed in the search field.
    case search(String)
}
