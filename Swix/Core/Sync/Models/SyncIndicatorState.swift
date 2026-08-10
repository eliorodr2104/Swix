//
//  SyncIndicatorState.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Whether the room list's "still syncing" indicator should be visible right now.
///
/// The SDK already debounces both edges (a short delay before showing, a shorter one before
/// hiding), so a view bound to this can flip the indicator directly with no debounce of its own.
enum SyncIndicatorState: Equatable {

    /// Sync caught up; nothing to show.
    case hidden

    /// The initial sync or a long catch up is still running.
    case visible
}
