//
//  FoundUserMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Turns the SDK's user directory answer into domain users.
enum FoundUserMapper {

    /// Maps a whole answer. The SDK's `limited` flag is dropped on purpose: the directory has no
    /// pagination, so the only honest thing a UI can do with it is nothing.
    static func makeUsers(from results: SearchUsersResults) -> [FoundUser] {
        results.results.map { makeUser(from: $0) }
    }

    /// Maps a single directory entry, keeping only what a result row needs.
    static func makeUser(from profile: UserProfile) -> FoundUser {
        FoundUser(
            userID     : profile.userId,
            displayName: profile.displayName,
            avatarURL  : profile.avatarUrl
        )
    }
}
