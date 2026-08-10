//
//  ReceiptKind.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Which of the three read markers Matrix defines an operation should move.
///
/// The distinction matters to other people, not to us: a public receipt is visible to the whole
/// room, a private one only tells our own homeserver how far we got, and the fully read marker is
/// the "resume here" line the user sees when they come back to a room.
enum ReceiptKind: Equatable {

    /// The receipt everybody in the room can see, which is what drives their read indicators.
    case read

    /// The same position, kept private to the account.
    case readPrivate

    /// The read marker line, which moves independently of the two receipts above.
    case fullyRead
}
