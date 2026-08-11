//
//  CoreEnvironment.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import SwiftUI


/// The Core's only SwiftUI facing surface: the environment keys a view reads its dependencies from.
///
/// This is the one file in the Core that imports SwiftUI, which is what keeps every layer beneath it
/// testable without a view hierarchy.
///
/// Every entry is optional and defaults to nil, because none of these can be conjured out of thin
/// air: `CoreContainer` has to be built by the app and the session scoped view models only exist
/// while an account is signed in. A view that finds nil is a view that was placed outside the part
/// of the tree where the container was injected, and the empty state it renders says so honestly.
///
/// Only `coreContainer` and the two session view models are worth injecting at the root, since they
/// live as long as the process does. The rest come and go with the session, so a root view injects
/// them from `container.scope` once it exists and lets them disappear with it, and any screen that
/// prefers to read `scope` directly is free to ignore them entirely.
extension EnvironmentValues {

    /// The Core's root. Injected once, by the app entry point, above everything else.
    @Entry var coreContainer: CoreContainer? = nil

    /// Drives the choice between the splash, the login and the app.
    @Entry var sessionViewModel: SessionViewModel? = nil

    /// The login form.
    @Entry var loginViewModel: LoginViewModel? = nil

    /// The room list, with its search field and its row actions.
    @Entry var chatListViewModel: ChatListViewModel? = nil

    /// The account's own display name and avatar.
    @Entry var profileViewModel: ProfileViewModel? = nil

    /// The session verification flow, incoming or outgoing.
    @Entry var sessionVerificationViewModel: SessionVerificationViewModel? = nil

    /// The active call, for the screen that hosts the Element Call webview.
    @Entry var callViewModel: CallViewModel? = nil

    /// Notification defaults and per room overrides.
    @Entry var notificationSettingsViewModel: NotificationSettingsViewModel? = nil

    /// The ignore list.
    @Entry var ignoredUsersViewModel: IgnoredUsersViewModel? = nil

    /// Full text search over the local event index.
    @Entry var messageSearchViewModel: MessageSearchViewModel? = nil

    /// Public room directory search.
    @Entry var roomDirectoryViewModel: RoomDirectoryViewModel? = nil

    /// User directory search.
    @Entry var userSearchViewModel: UserSearchViewModel? = nil

    /// Authenticated Matrix media, for the image views: avatars and attachments are mxc URIs
    /// behind the account's token, so they load through the Core rather than through a URL.
    @Entry var mediaService: (any MediaServiceProtocol)? = nil
}
