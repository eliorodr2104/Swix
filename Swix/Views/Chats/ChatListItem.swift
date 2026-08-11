//
//  ChatListItem.swift
//  Swix
//
//  Created by Eliomar on 11/08/2026.
//

import Foundation


/// The chat list flattened into a single sequence, group titles included, instead of the two
/// separate groups it looks like on screen. This is what makes a pin animate: with one flat array
/// behind one `ForEach`, pinning a chat is a reorder of elements that keep their identity, which
/// SwiftUI interpolates into a slide, while two `ForEach`es could only ever remove the row from one
/// and insert it into the other.
enum ChatListItem: Identifiable {

    /// A group title. It carries its own text because that text is the only thing distinguishing
    /// one title from another.
    case header(String)

    /// A chat row, holding the summary the row renders itself from.
    case room(RoomSummary)

    /// What SwiftUI diffs the list on, so it has to stay stable across rebuilds and unique inside
    /// the array. Titles are namespaced by hand while rooms answer with their Matrix room id, which
    /// always starts with "!" and therefore can never collide with a namespaced title.
    var id: String {

        switch self {
            case .header(let title):
                "header-\(title)"

            case .room(let summary):
                summary.id
        }
    }
}
