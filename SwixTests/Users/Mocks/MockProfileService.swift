//
//  MockProfileService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
@testable import Swix


/// Records every profile read and write `OwnProfileRepository` makes, and lets a test push later
/// own-profile updates through `ownProfileStream`.
final class MockProfileService: ProfileServiceProtocol {

    let ownProfileStream: AsyncStream<UserProfileInfo>

    let ownProfileContinuation: AsyncStream<UserProfileInfo>.Continuation

    var stubbedOwnProfile = UserProfileInfo(
        userID     : "@alice:example.org",
        displayName: "Alice",
        avatarURL  : nil,
        status     : nil,
        isInCall   : false
    )

    private(set) var setDisplayNameCalls: [String] = []

    private(set) var uploadAvatarCalls: [(data: Data, mimeType: String)] = []

    private(set) var removeAvatarCallCount = 0

    private(set) var startObservingCallCount = 0

    private(set) var shutdownCallCount = 0

    var fetchError: (any Error)?

    var writeError: (any Error)?

    var startObservingError: (any Error)?

    init() {
        (ownProfileStream, ownProfileContinuation) = AsyncStream<UserProfileInfo>.makeStream(bufferingPolicy: .unbounded)
    }

    func fetchOwnProfile() async throws -> UserProfileInfo {
        if let fetchError {
            throw fetchError
        }

        return stubbedOwnProfile
    }

    func getProfile(userID: String) async throws -> UserProfileInfo {
        if let fetchError {
            throw fetchError
        }

        return UserProfileInfo(userID: userID, displayName: nil, avatarURL: nil, status: nil, isInCall: false)
    }

    func setDisplayName(_ name: String) async throws {
        setDisplayNameCalls.append(name)

        if let writeError {
            throw writeError
        }
    }

    func uploadAvatar(data: Data, mimeType: String) async throws {
        uploadAvatarCalls.append((data, mimeType))

        if let writeError {
            throw writeError
        }
    }

    func removeAvatar() async throws {
        removeAvatarCallCount += 1

        if let writeError {
            throw writeError
        }
    }

    func startObservingOwnProfile() throws {
        startObservingCallCount += 1

        if let startObservingError {
            throw startObservingError
        }
    }

    func shutdown() {
        shutdownCallCount += 1
    }
}
