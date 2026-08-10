//
//  UserSearchRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Observation
import os


/// The single source of truth for the user directory results.
@Observable
final class UserSearchRepository {

    /// Users the directory returned for the current term, in server ranked order.
    private(set) var users: [FoundUser] = []

    /// Where the current term stands. The directory answers in one shot, so a finished search is
    /// always `.loaded(hasMoreResults: false)`.
    private(set) var loadState: SearchLoadState = .idle

    /// The last failure, kept until the next attempt clears it.
    private(set) var failure: SearchFailure?

    @ObservationIgnored
    private let service: any UserSearchServiceProtocol

    @ObservationIgnored
    private let resultLimit: Int

    @ObservationIgnored
    private var currentTerm = ""

    @ObservationIgnored
    private var generation = 0

    init(
        service    : any UserSearchServiceProtocol,
        resultLimit: Int = Int(MatrixConfiguration.directorySearchPageSize)
    ) {
        self.service = service
        self.resultLimit = resultLimit
    }

    /// Runs a new query, or clears everything when the term is empty. Repeating the term that is
    /// already loaded does nothing, so a view model is free to call this on every keystroke.
    func search(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedQuery != currentTerm else {
            return
        }

        currentTerm = trimmedQuery

        guard !trimmedQuery.isEmpty else {
            clear()

            return
        }

        generation += 1

        let requestGeneration = generation

        failure = nil
        loadState = .loading

        do {
            let found = try await service.searchUsers(matching: trimmedQuery, limit: resultLimit)

            // A slower answer to an older term must never overwrite a newer one, and the request
            // itself cannot be cancelled once it is in flight across the FFI.
            guard requestGeneration == generation else {
                return
            }

            users = found
            loadState = .loaded(hasMoreResults: false)
        } catch {
            guard requestGeneration == generation else {
                return
            }

            record(error)
        }
    }

    /// Drops the current term and every result, and makes any answer still in flight irrelevant.
    func clear() {
        generation += 1
        currentTerm = ""
        users.removeAll()
        failure = nil
        loadState = .idle
    }

    private func record(_ error: any Error) {
        let searchFailure = error as? SearchFailure ?? .userSearchFailed(SDKErrorInfo(error))

        Log.search.error("User search failed: \(String(reflecting: error), privacy: .public)")

        failure = searchFailure
        loadState = .loaded(hasMoreResults: false)
    }
}
