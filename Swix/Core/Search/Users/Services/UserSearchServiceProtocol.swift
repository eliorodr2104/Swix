//
//  UserSearchServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Queries the homeserver's user directory.
protocol UserSearchServiceProtocol {

    /// Asks the directory for users matching a term, capped at `limit` entries. The homeserver
    /// does the ranking, so results come back in the order it considers most relevant.
    func searchUsers(
        matching term: String,
        limit        : Int
    ) async throws -> [FoundUser]
}
