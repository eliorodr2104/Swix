//
//  ProfileServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Reads and writes the signed in user's own profile, and looks up any other user's.
protocol ProfileServiceProtocol {

    /// Live updates to the signed in user's own profile. Nothing arrives until
    /// `startObservingOwnProfile()` has been called at least once.
    var ownProfileStream: AsyncStream<UserProfileInfo> { get }

    /// Fetches the signed in user's own profile directly, without waiting for a push update.
    func fetchOwnProfile() async throws -> UserProfileInfo

    /// Fetches any user's public profile by id.
    func getProfile(userID: String) async throws -> UserProfileInfo

    /// Changes the signed in user's display name.
    func setDisplayName(_ name: String) async throws

    /// Uploads new avatar bytes and sets the result as the signed in user's avatar.
    func uploadAvatar(data: Data, mimeType: String) async throws

    /// Removes the signed in user's avatar.
    func removeAvatar() async throws

    /// Starts forwarding SDK own-profile updates onto `ownProfileStream`. Safe to call more than
    /// once: a client already being observed is left untouched.
    func startObservingOwnProfile() throws

    /// Releases the own-profile subscription. Called once, when the session ends.
    func shutdown()
}
