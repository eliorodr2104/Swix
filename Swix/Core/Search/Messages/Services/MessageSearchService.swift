//
//  MessageSearchService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// The default `MessageSearchServiceProtocol`, built on `Client.searchService()`.
///
/// The heavy lifting happens in the SDK's native Tantivy index, configured at client build time,
/// so nothing here ranks or filters: it only maps and forwards.
final class MessageSearchService: MessageSearchServiceProtocol {

    let resultDiffs: AsyncStream<[CollectionDiff<MessageSearchResult>]>

    let loadStates: AsyncStream<SearchLoadState>

    private let clientService: any ClientServiceProtocol

    private let diffContinuation: AsyncStream<[CollectionDiff<MessageSearchResult>]>.Continuation

    private let loadStateContinuation: AsyncStream<SearchLoadState>.Continuation

    private let subscriptions = SubscriptionBag()

    private var searchService: SearchService?

    private var roomNames: [String: String] = [:]

    init(clientService: any ClientServiceProtocol) {
        self.clientService = clientService

        (resultDiffs, diffContinuation) = AsyncStream<[CollectionDiff<MessageSearchResult>]>.makeStream(bufferingPolicy: .unbounded)
        (loadStates, loadStateContinuation) = AsyncStream<SearchLoadState>.makeStream(bufferingPolicy: .unbounded)
    }

    func setQuery(_ query: String) async throws {
        let service = try await activeSearchService()

        do {
            try await service.setQuery(query: query)
        } catch {
            throw SearchFailure.queryFailed(SDKErrorInfo(error))
        }
    }

    func paginate() async throws {
        let service = try await activeSearchService()

        do {
            try await service.paginate()
        } catch {
            throw SearchFailure.paginationFailed(SDKErrorInfo(error))
        }
    }

    func shutdown() {
        subscriptions.cancelAll()
        searchService = nil
        roomNames.removeAll()

        diffContinuation.finish()
        loadStateContinuation.finish()
    }

    /// Builds the SDK search service exactly once and wires its two listeners. Rebuilding it per
    /// query would throw away the warm index handle, which is the whole point of the native index.
    private func activeSearchService() async throws -> SearchService {
        if let searchService {
            return searchService
        }

        guard let client = clientService.sdkClient else {
            throw SearchFailure.noActiveClient
        }

        let service = client.searchService()

        searchService = service
        await observe(service)

        return service
    }

    private func observe(_ service: SearchService) async {
        let (rawResults, resultsListener) = makeSDKStream(of: [SearchServiceResultsUpdate].self)

        subscriptions.retain(await service.subscribeToResults(listener: resultsListener))
        subscriptions.retain(Task { [weak self] in
            for await updates in rawResults {
                guard let self else {
                    return
                }

                diffContinuation.yield(MessageSearchResultMapper.makeDiffs(from: updates) { roomName(for: $0) })
            }
        })

        let (rawStates, stateListener) = makeSDKStream(of: SearchServicePaginationState.self)

        subscriptions.retain(service.subscribeToPaginationStateUpdates(listener: stateListener))
        subscriptions.retain(Task { [loadStateContinuation] in
            for await state in rawStates {
                loadStateContinuation.yield(SearchLoadStateMapper.makeLoadState(from: state))
            }
        })
    }

    /// Room names are resolved once per room and cached, because a single batch routinely carries
    /// dozens of hits from the same room and every lookup crosses the FFI into the state store.
    private func roomName(for roomID: String) -> String? {
        if let cached = roomNames[roomID] {
            return cached
        }

        guard let client = clientService.sdkClient,
              let room = try? client.getRoom(roomId: roomID),
              let name = room.displayName() else {
            return nil
        }

        roomNames[roomID] = name

        return name
    }
}
