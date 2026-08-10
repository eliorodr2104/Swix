//
//  RoomDirectorySearchService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// The default `RoomDirectorySearchServiceProtocol`, built on `Client.roomDirectorySearch()`.
final class RoomDirectorySearchService: RoomDirectorySearchServiceProtocol {

    let resultDiffs: AsyncStream<[CollectionDiff<DirectoryRoom>]>

    private let clientService: any ClientServiceProtocol

    private let diffContinuation: AsyncStream<[CollectionDiff<DirectoryRoom>]>.Continuation

    private let subscriptions = SubscriptionBag()

    private var directorySearch: RoomDirectorySearch?

    init(clientService: any ClientServiceProtocol) {
        self.clientService = clientService

        (resultDiffs, diffContinuation) = AsyncStream<[CollectionDiff<DirectoryRoom>]>.makeStream(bufferingPolicy: .unbounded)
    }

    func search(
        filter       : String?,
        viaServerName: String?
    ) async throws {
        let search = try await activeDirectorySearch()

        do {
            try await search.search(
                filter       : filter,
                batchSize    : MatrixConfiguration.directorySearchPageSize,
                viaServerName: viaServerName
            )
        } catch {
            throw SearchFailure.directoryFailed(SDKErrorInfo(error))
        }
    }

    func loadNextPage() async throws {
        let search = try await activeDirectorySearch()

        do {
            try await search.nextPage()
        } catch {
            throw SearchFailure.paginationFailed(SDKErrorInfo(error))
        }
    }

    func isAtLastPage() async throws -> Bool {
        let search = try await activeDirectorySearch()

        do {
            return try await search.isAtLastPage()
        } catch {
            throw SearchFailure.directoryFailed(SDKErrorInfo(error))
        }
    }

    func shutdown() {
        subscriptions.cancelAll()
        directorySearch = nil

        diffContinuation.finish()
    }

    /// One directory search object serves every query of the session: the SDK clears its own
    /// results whenever a new `search` starts, so rebuilding it would only drop the results
    /// listener and lose the first batch of the next query.
    private func activeDirectorySearch() async throws -> RoomDirectorySearch {
        if let directorySearch {
            return directorySearch
        }

        guard let client = clientService.sdkClient else {
            throw SearchFailure.noActiveClient
        }

        let search = client.roomDirectorySearch()

        directorySearch = search
        await observe(search)

        return search
    }

    private func observe(_ search: RoomDirectorySearch) async {
        let (rawUpdates, listener) = makeSDKStream(of: [RoomDirectorySearchEntryUpdate].self)

        subscriptions.retain(await search.results(listener: listener))
        subscriptions.retain(Task { [diffContinuation] in
            for await updates in rawUpdates {
                diffContinuation.yield(DirectoryRoomMapper.makeDiffs(from: updates))
            }
        })
    }
}
