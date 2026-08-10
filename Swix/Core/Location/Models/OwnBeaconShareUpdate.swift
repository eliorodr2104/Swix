//
//  OwnBeaconShareUpdate.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// A change to the account's own live location share, in whichever room it happened.
///
/// This is client wide by nature: `Client.subscribeToOwnBeaconInfoUpdates` reports every room the
/// account is sharing in through the same listener, so the room id travels with each update
/// rather than being implied by which stream it arrived on.
struct OwnBeaconShareUpdate: Equatable {

    /// The room the share lives in.
    let roomID: String

    /// The beacon_info event id backing the share, needed to tell two updates for the same room
    /// apart if the account ever restarts a share there.
    let eventID: String

    /// Whether the share is still active after this update.
    let isLive: Bool
}
