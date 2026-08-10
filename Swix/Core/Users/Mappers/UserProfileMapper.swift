//
//  UserProfileMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Translates the SDK's `UserProfile` and `UserStatus` into this feature's domain models.
enum UserProfileMapper {

    /// Projects the SDK profile onto the domain model, resolving the MSC4426 status and call
    /// fields so a view never has to reach for the SDK types to read them.
    static func makeUserProfileInfo(from profile: UserProfile) -> UserProfileInfo {
        UserProfileInfo(
            userID     : profile.userId,
            displayName: profile.displayName,
            avatarURL  : profile.avatarUrl,
            status     : profile.status.map(makeUserStatusInfo),
            isInCall   : profile.call != nil
        )
    }

    /// Turns an MSC4426 status coming from the SDK into the domain model.
    static func makeUserStatusInfo(from status: UserStatus) -> UserStatusInfo {
        UserStatusInfo(emoji: status.emoji, text: status.text)
    }

    /// Turns a domain status back into what `Client.setUserStatus` expects.
    static func makeSDKUserStatus(from status: UserStatusInfo) -> UserStatus {
        UserStatus(emoji: status.emoji, text: status.text)
    }
}
