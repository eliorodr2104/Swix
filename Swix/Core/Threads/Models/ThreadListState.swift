//
//  ThreadListState.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Where a room's thread list stands: whether a page is in flight, and whether any are left.
///
/// This is deliberately not the timeline's `PaginationState`, even though both have two cases: a
/// timeline walks backwards into history and reports having reached the start of the room, while a
/// thread list walks forwards through pages and reports having reached the end of the list. Sharing
/// one type would mean one of the two reading its own state backwards.
enum ThreadListState: Equatable {

    /// Nothing in flight. `hasReachedEnd` tells whether another page would find anything.
    case idle(hasReachedEnd: Bool)

    /// A page of threads is on its way.
    case loading

    /// Whether a spinner belongs on screen.
    var isLoading: Bool {
        self == .loading
    }

    /// Whether the last page of the list has already been handed over.
    var hasReachedEnd: Bool {
        guard case .idle(let hasReachedEnd) = self else {
            return false
        }

        return hasReachedEnd
    }

    /// Whether asking for one more page is worth doing right now.
    var canLoadMore: Bool {
        !isLoading && !hasReachedEnd
    }
}
