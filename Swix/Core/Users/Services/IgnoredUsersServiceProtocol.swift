//
//  IgnoredUsersServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Reads, changes and observes the signed in user's ignore list.
protocol IgnoredUsersServiceProtocol {

    /// Live updates to the ignore list. Nothing arrives until `startObservingIgnoredUsers()` has
    /// been called at least once.
    var ignoredUserIDsStream: AsyncStream<[String]> { get }

    /// Fetches the current ignore list directly, without waiting for a push update.
    func fetchIgnoredUserIDs() async throws -> [String]

    /// Adds a user to the ignore list.
    func ignore(userID: String) async throws

    /// Removes a user from the ignore list.
    func unignore(userID: String) async throws

    /// Starts forwarding SDK ignore list updates onto `ignoredUserIDsStream`. Safe to call more
    /// than once: a client already being observed is left untouched.
    func startObservingIgnoredUsers() throws

    /// Releases the ignore list subscription. Called once, when the session ends.
    func shutdown()
}
