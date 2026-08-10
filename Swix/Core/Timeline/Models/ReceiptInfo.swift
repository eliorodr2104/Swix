//
//  ReceiptInfo.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// A single read receipt: who read, and how far they got.
///
/// Two things produce one of these. A message entry carries the receipts that landed on that exact
/// event, so `eventID` is redundant there and stays nil; a receipt looked up on its own through
/// `TimelineServiceProtocol.loadReceipt(_:ofUser:)` names the event it points at instead.
struct ReceiptInfo: Identifiable, Equatable {

    /// The Matrix user this receipt belongs to.
    let userID: String

    /// The event the receipt points at, nil when it was read off the event that carries it.
    let eventID: String?

    /// When the receipt was sent, absent when the homeserver did not timestamp it.
    let timestamp: Date?

    /// One user has at most one receipt per event, so the user id is identity enough.
    var id: String {
        userID
    }
}
