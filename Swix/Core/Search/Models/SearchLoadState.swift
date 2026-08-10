//
//  SearchLoadState.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Where a paginated search stands right now, shared by the message, room directory and user
/// searches so a screen showing more than one of them speaks a single vocabulary.
enum SearchLoadState: Equatable {

    /// No query has been submitted yet, or the query was cleared.
    case idle

    /// A page is in flight.
    case loading

    /// A page landed. `hasMoreResults` is false once the backing source is exhausted.
    case loaded(hasMoreResults: Bool)

    /// Whether a spinner belongs on screen.
    var isLoading: Bool {
        self == .loading
    }

    /// Whether asking for one more page would do anything.
    var canLoadMore: Bool {
        self == .loaded(hasMoreResults: true)
    }
}
