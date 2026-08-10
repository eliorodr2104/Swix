//
//  SearchLoadStateMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Turns the SDK's pagination state into the domain load state the three searches share.
enum SearchLoadStateMapper {

    /// Maps `SearchServicePaginationState`. The SDK reports "idle plus end reached" while the
    /// domain reports "loaded plus there is more", which is the question a list view actually asks.
    static func makeLoadState(from state: SearchServicePaginationState) -> SearchLoadState {
        switch state {
            case .idle(let endReached): .loaded(hasMoreResults: !endReached)
            case .loading: .loading
        }
    }
}
