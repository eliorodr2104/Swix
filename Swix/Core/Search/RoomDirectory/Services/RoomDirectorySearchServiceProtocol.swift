//
//  RoomDirectorySearchServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Drives the homeserver's public room directory and republishes it as domain diffs.
protocol RoomDirectorySearchServiceProtocol {

    /// Batches of changes to the directory list, already mapped out of the SDK.
    var resultDiffs: AsyncStream<[CollectionDiff<DirectoryRoom>]> { get }

    /// Starts a new search, clearing whatever the previous one had loaded. A nil filter browses
    /// the whole directory, a nil server name stays on the account's own homeserver.
    func search(
        filter       : String?,
        viaServerName: String?
    ) async throws

    /// Asks the server for the next page of the current search.
    func loadNextPage() async throws

    /// Whether the current search has reached the end of the directory.
    func isAtLastPage() async throws -> Bool

    /// Releases every subscription this service owns. Called once, when the session ends.
    func shutdown()
}
