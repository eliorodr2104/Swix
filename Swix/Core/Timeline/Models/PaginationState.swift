//
//  PaginationState.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Whether the timeline is currently fetching older events, and whether any are left.
///
/// The SDK reports this as its own two case status, and both halves matter to the UI: one drives
/// the spinner at the top of the list, the other decides whether scrolling up should ask for more
/// at all.
enum PaginationState: Equatable {

    /// Nothing in flight. `hasReachedStart` tells whether another request would find anything.
    case idle(hasReachedStart: Bool)

    /// A back pagination request is already running, so asking again would be wasted.
    case paginating

    /// Whether a request is in flight right now.
    var isPaginating: Bool {
        self == .paginating
    }

    /// Whether the very beginning of the room's history is already loaded.
    var hasReachedStart: Bool {
        guard case .idle(let hasReachedStart) = self else {
            return false
        }

        return hasReachedStart
    }

    /// Whether asking for older events is worth doing right now.
    var canPaginate: Bool {
        !isPaginating && !hasReachedStart
    }
}
