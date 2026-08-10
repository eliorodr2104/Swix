//
//  MessageSearchServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Drives the SDK's local full text index and republishes it as domain diffs.
protocol MessageSearchServiceProtocol {

    /// Batches of changes to the result list, already mapped out of the SDK.
    var resultDiffs: AsyncStream<[CollectionDiff<MessageSearchResult>]> { get }

    /// Pagination state of the current query.
    var loadStates: AsyncStream<SearchLoadState> { get }

    /// Replaces the query, which clears the results and loads the first page.
    func setQuery(_ query: String) async throws

    /// Loads one more page of the current query. A no-op once the index is exhausted.
    func paginate() async throws

    /// Releases every subscription this service owns. Called once, when the session ends.
    func shutdown()
}
