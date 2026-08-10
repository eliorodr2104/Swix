//
//  LiveLocationShare.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// One account's live location share inside a room: where they last were, and when the share
/// stops being live on its own if nothing else arrives.
struct LiveLocationShare: Identifiable, Equatable {

    /// The Matrix user sharing their location. A room's active shares are keyed by this, since the
    /// SDK only ever surfaces one live beacon per user at a time.
    let userID: String

    /// Where the share last put them, nil for the brief window between starting a share and its
    /// first beacon update arriving.
    let lastKnown: LastKnownLocation?

    /// When this share's own deadline passes, absent any update that pushes it back.
    let expiresAt: Date

    /// One user has at most one live share per room, so the user id is identity enough.
    var id: String {
        userID
    }

    /// Whether this share's deadline has already passed, for shares the list has not yet been
    /// told to drop.
    var hasExpired: Bool {
        expiresAt <= Date()
    }
}
