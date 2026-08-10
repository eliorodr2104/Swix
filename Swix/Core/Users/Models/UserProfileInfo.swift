//
//  UserProfileInfo.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// A Matrix user's public profile, named to avoid clashing with the SDK's own `UserProfile`.
struct UserProfileInfo: Equatable, Identifiable {

    /// The Matrix user identifier this profile belongs to, for instance `@alice:matrix.org`.
    let userID: String

    /// The user's chosen display name, if any.
    let displayName: String?

    /// The `mxc://` URI of the user's avatar, if any.
    let avatarURL: String?

    /// The MSC4426 status the user is currently showing, if any.
    let status: UserStatusInfo?

    /// Whether the profile advertises the user as being in a call right now (MSC4426 `m.call`).
    let isInCall: Bool

    /// Identity for SwiftUI's own diffing, which is the Matrix ID: a display name changes, the id
    /// the row stands for does not.
    var id: String { userID }

    init(
        userID     : String,
        displayName: String?,
        avatarURL  : String?,
        status     : UserStatusInfo?,
        isInCall   : Bool
    ) {

        self.userID = userID
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.status = status
        self.isInCall = isInCall
    }
}
