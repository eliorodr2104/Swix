//
//  UserSessionScope.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import os


/// Everything that lives and dies with one signed in client, assembled in a single place so that
/// no feature ever has to go looking for its own dependencies.
///
/// A scope is created by `CoreContainer` the moment a session becomes authenticated and released
/// the moment it stops being one, because every listener underneath is registered on an SDK client
/// that is about to be dropped. Anything narrower than a session, one room's conversation or one
/// room's settings form, is deliberately not stored here: the `make...` factories build it on
/// demand and hand ownership to the screen that asked, which then tears it down on its way out.
///
/// The scope is not `@Observable` on purpose. Nothing on it ever changes; the state views watch
/// lives in the repositories and view models it holds, and those are observable themselves.
final class UserSessionScope {

    /// The account this scope was built for, which is also how `CoreContainer` tells a session
    /// that merely refreshed from one that was replaced by another account.
    let userSession: UserSession

    /// Owns the SDK sync engine and, through it, the room list every other feature reads rooms from.
    let syncCoordinator: SyncCoordinator

    /// Whether sync is running, and the debounced indicator the room list shows while it catches up.
    let syncRepository: SyncRepository

    /// Pauses and resumes sync as the app changes scene phase. Driven by `CoreContainer`.
    let syncLifecycleController: SyncLifecycleController

    /// Favourites, low priority, read markers and recently visited, for rows and context menus.
    let roomActionsService: RoomActionsService

    /// The paged, filtered, sorted room list. Bound to the chat list screen.
    let roomListRepository: RoomListRepository

    /// What the chat list screen binds to, search field and all.
    let chatListViewModel: ChatListViewModel

    /// Hands out and caches the conversations of this session, threads included.
    let timelineProvider: TimelineProvider

    /// Device trust, recovery and key backup states, plus the operations that change them.
    let encryptionRepository: EncryptionRepository

    /// One session verification flow at a time, incoming or outgoing.
    let sessionVerificationRepository: SessionVerificationRepository

    /// What a verification sheet binds to: the emoji, the accept and the decline.
    let sessionVerificationViewModel: SessionVerificationViewModel

    /// Mints the short lived OpenID tokens an SFU asks for before it will accept this account.
    let openIdTokenService: OpenIdTokenService

    /// The one active call of this session, if there is one.
    let callRepository: CallRepository

    /// What a call screen binds to, including the message channel a `WKWebView` attaches to.
    let callViewModel: CallViewModel

    /// Reads and writes thread subscriptions. Stateless, so one instance serves every room.
    let threadSubscriptionService: ThreadSubscriptionService

    /// Account wide notification defaults and the per room overrides that sit on top of them.
    let notificationSettingsRepository: NotificationSettingsRepository

    /// What a notification settings screen binds to.
    let notificationSettingsViewModel: NotificationSettingsViewModel

    /// Registers and removes this device's push endpoint. Called by whoever owns the APNs token.
    let pusherService: PusherService

    /// Resolves notifications into something displayable, and forwards the ones sync raises.
    ///
    /// Built without a `NotificationSyncServiceProviding`: `SyncCoordinator` keeps its `SyncService`
    /// private, so the notification client gets its own rather than sharing the running loop. A
    /// Notification Service Extension is in exactly the same position, which is why the service was
    /// designed to work either way.
    let notificationItemService: NotificationItemService

    /// Full text search across the local event index of this session.
    let messageSearchRepository: MessageSearchRepository

    /// What a message search screen binds to, debounce included.
    let messageSearchViewModel: MessageSearchViewModel

    /// Public room directory search, paged.
    let roomDirectoryRepository: RoomDirectoryRepository

    /// What a room directory screen binds to.
    let roomDirectoryViewModel: RoomDirectoryViewModel

    /// User directory search, for starting a conversation or inviting someone.
    let userSearchRepository: UserSearchRepository

    /// What a user search screen binds to.
    let userSearchViewModel: UserSearchViewModel

    /// Presence and the custom status message, both written straight to the homeserver.
    let presenceService: PresenceService

    /// The account's own profile: display name and avatar, kept in step with the homeserver.
    let ownProfileRepository: OwnProfileRepository

    /// What a profile screen binds to.
    let profileViewModel: ProfileViewModel

    /// The ignore list, and the two operations that change it.
    let ignoredUsersRepository: IgnoredUsersRepository

    /// What an ignored users screen binds to.
    let ignoredUsersViewModel: IgnoredUsersViewModel

    /// Authenticated media downloads and thumbnails, the layer image views load through: Matrix
    /// media lives behind mxc URIs and the account's token, out of reach of any plain URL loader.
    let mediaService: MediaService

    /// Uploads, downloads, thumbnails and the on disk thumbnail cache.
    let mediaRepository: MediaRepository

    /// Optional homeserver side malware scanning, off until `configure(scannerURL:)` is called.
    let contentScannerService: ContentScannerService

    /// One-shot locations and live location sharing, session wide because a beacon outlives a screen.
    let locationService: LocationService

    /// Global account data, read, written and observed.
    let accountDataRepository: AccountDataRepository

    /// Room account data and the typed helpers, for the events no repository wraps yet.
    let accountDataService: AccountDataService

    /// Room metadata edits: name, topic, avatar, join rule, visibility and encryption.
    let roomSettingsService: RoomSettingsService

    /// Builds every stack of one session, wiring each feature onto the client that owns it.
    ///
    /// Nothing here talks to the network: construction is pure assembly, and the first request only
    /// leaves once `start()` runs. That is what makes the scope safe to build on the main thread the
    /// instant the session turns authenticated.
    init(
        userSession  : UserSession,
        clientService: any ClientServiceProtocol
    ) {
        self.userSession = userSession

        let syncCoordinator = SyncCoordinator(clientService: clientService)

        self.syncCoordinator = syncCoordinator

        let syncRepository = SyncRepository(coordinator: syncCoordinator)

        self.syncRepository          = syncRepository
        self.syncLifecycleController = SyncLifecycleController(repository: syncRepository)

        let roomListEntriesService = RoomListEntriesService(
            coordinator: syncCoordinator,
            ownUserID  : userSession.userID
        )
        let roomListRepository     = RoomListRepository(entriesService: roomListEntriesService)

        let roomActionsService = RoomActionsService(
            roomProvider : syncCoordinator,
            clientService: clientService
        )

        self.roomActionsService = roomActionsService
        self.roomListRepository = roomListRepository

        // Built before the chat list because muting a room from its context menu is a
        // notification rule, not a room flag.
        let notificationSettingsRepository = NotificationSettingsRepository(
            settingsService: NotificationSettingsService(clientService: clientService)
        )

        self.notificationSettingsRepository = notificationSettingsRepository
        self.notificationSettingsViewModel  = NotificationSettingsViewModel(
            repository: notificationSettingsRepository
        )

        self.chatListViewModel = ChatListViewModel(
            repository                    : roomListRepository,
            actionsService                : roomActionsService,
            syncRepository                : syncRepository,
            notificationSettingsRepository: notificationSettingsRepository
        )

        let timelineProvider = TimelineProvider(
            clientService: clientService,
            roomProvider : syncCoordinator
        )

        self.timelineProvider = timelineProvider

        self.encryptionRepository = EncryptionRepository(
            service: EncryptionService(clientService: clientService)
        )

        let sessionVerificationRepository = SessionVerificationRepository(
            service: SessionVerificationService(clientService: clientService)
        )

        self.sessionVerificationRepository = sessionVerificationRepository
        self.sessionVerificationViewModel  = SessionVerificationViewModel(
            repository: sessionVerificationRepository
        )

        self.openIdTokenService = OpenIdTokenService(clientService: clientService)

        let callRepository = CallRepository(
            widgetService: CallWidgetService(
                roomProvider : syncCoordinator,
                clientService: clientService
            )
        )

        self.callRepository = callRepository
        self.callViewModel  = CallViewModel(repository: callRepository)

        self.threadSubscriptionService = ThreadSubscriptionService(roomProvider: syncCoordinator)

        self.pusherService           = PusherService(clientService: clientService)
        self.notificationItemService = NotificationItemService(clientService: clientService)

        let messageSearchRepository = MessageSearchRepository(
            service: MessageSearchService(clientService: clientService)
        )

        self.messageSearchRepository = messageSearchRepository
        self.messageSearchViewModel  = MessageSearchViewModel(repository: messageSearchRepository)

        let roomDirectoryRepository = RoomDirectoryRepository(
            service: RoomDirectorySearchService(clientService: clientService)
        )

        self.roomDirectoryRepository = roomDirectoryRepository
        self.roomDirectoryViewModel  = RoomDirectoryViewModel(repository: roomDirectoryRepository)

        let userSearchRepository = UserSearchRepository(
            service: UserSearchService(clientService: clientService)
        )

        self.userSearchRepository = userSearchRepository
        self.userSearchViewModel  = UserSearchViewModel(repository: userSearchRepository)

        self.presenceService = PresenceService(clientService: clientService)

        let ownProfileRepository = OwnProfileRepository(
            profileService: ProfileService(clientService: clientService)
        )

        self.ownProfileRepository = ownProfileRepository
        self.profileViewModel     = ProfileViewModel(repository: ownProfileRepository)

        let ignoredUsersRepository = IgnoredUsersRepository(
            ignoredUsersService: IgnoredUsersService(clientService: clientService)
        )

        self.ignoredUsersRepository = ignoredUsersRepository
        self.ignoredUsersViewModel  = IgnoredUsersViewModel(repository: ignoredUsersRepository)

        let mediaService = MediaService(clientService: clientService)

        self.mediaService    = mediaService
        self.mediaRepository = MediaRepository(mediaService: mediaService)

        self.contentScannerService = ContentScannerService(clientService: clientService)

        self.locationService = LocationService(
            clientService   : clientService,
            roomProvider    : syncCoordinator,
            timelineProvider: timelineProvider
        )

        let accountDataService = AccountDataService(clientService: clientService)

        self.accountDataService    = accountDataService
        self.accountDataRepository = AccountDataRepository(service: accountDataService)

        self.roomSettingsService = RoomSettingsService(roomProvider: syncCoordinator)
    }

    /// Brings the session to life: sync first, then everything that reads through it.
    ///
    /// The order is not cosmetic. The room list is served by the sync engine's own room list
    /// service, so asking for it before sync has been built fails outright; encryption and the
    /// notification bridge only need a client, so they come after and cannot hold the list up.
    ///
    /// Nothing throws: each stack records its own failure where its screen can present it, and one
    /// feature failing to attach must not stop the others from working.
    func start() async {
        await syncRepository.start()
        await chatListViewModel.start()

        encryptionRepository.start()

        await startForwardingNotifications()

        Log.session.notice(
            "Session scope started for \(self.userSession.userID, privacy: .private)"
        )
    }

    /// Releases every listener, task and SDK handle this scope owns, in the reverse of the order
    /// they were built in.
    ///
    /// Sync goes last on purpose: it is what hands out the rooms the other features hold, so
    /// dropping it first would leave them tearing down against an engine that is already gone.
    ///
    /// Some of these are spelled `stop()` and some `shutdown()`. That is not drift: the folders
    /// that were restyled to the newer lifecycle naming use `shutdown()`, the ones that were not
    /// still use `stop()`, and both mean the same thing here.
    func shutdown() {
        accountDataRepository.shutdown()
        roomSettingsService.shutdown()
        locationService.shutdown()
        mediaRepository.shutdown()
        ignoredUsersViewModel.shutdown()
        profileViewModel.shutdown()

        // User search holds no SDK subscription of its own, so clearing the debounce task is the
        // whole of its teardown.
        userSearchViewModel.stop()
        roomDirectoryViewModel.stop()
        roomDirectoryRepository.shutdown()
        messageSearchViewModel.stop()
        messageSearchRepository.shutdown()
        notificationItemService.shutdown()
        notificationSettingsRepository.shutdown()
        callRepository.stop()
        sessionVerificationRepository.stop()
        encryptionRepository.stop()
        timelineProvider.shutdown()
        chatListViewModel.shutdown()
        syncLifecycleController.invalidate()
        syncRepository.shutdown()

        Log.session.notice(
            "Session scope shut down for \(self.userSession.userID, privacy: .private)"
        )
    }

    /// Builds one room's conversation, already started, for a chat screen to own.
    ///
    /// The screen calls `start()` on the returned view model and `shutdown()` when it goes away;
    /// once the user leaves the room for good, `releaseRoom(_:)` drops the cached timeline too.
    func makeChatViewModel(forRoom roomID: String) async throws -> ChatViewModel {
        let service = try await timelineProvider.liveTimeline(forRoom: roomID)

        return ChatViewModel(repository: TimelineRepository(service: service))
    }

    /// Builds the thread list of one room, for a thread list screen to own.
    ///
    /// Nothing is cached: a thread list is as cheap as its first page, so leaving and coming back
    /// simply builds another one.
    func makeThreadListViewModel(forRoom roomID: String) -> ThreadListViewModel {
        let service = ThreadListService(
            roomID      : roomID,
            roomProvider: syncCoordinator
        )

        let repository = ThreadListRepository(
            service            : service,
            subscriptionService: threadSubscriptionService
        )

        return ThreadListViewModel(repository: repository)
    }

    /// Builds one thread's conversation, for a thread screen to own.
    ///
    /// The view model builds its chat lazily in `open()`, so this call costs nothing and cannot
    /// fail; a thread that turns out not to exist surfaces as a failure on the view model.
    func makeThreadViewModel(
        roomID     : String,
        rootEventID: String
    ) -> ThreadViewModel {
        ThreadViewModel(
            roomID             : roomID,
            rootEventID        : rootEventID,
            timelineProvider   : timelineProvider,
            subscriptionService: threadSubscriptionService
        )
    }

    /// Builds the settings form of one room, for a settings screen to own.
    func makeRoomSettingsViewModel(forRoom roomID: String) -> RoomSettingsViewModel {
        RoomSettingsViewModel(
            repository: RoomSettingsRepository(
                roomID         : roomID,
                settingsService: roomSettingsService
            )
        )
    }

    /// Builds the live location map of one room, for a map screen to own.
    func makeLiveLocationViewModel(forRoom roomID: String) -> LiveLocationViewModel {
        LiveLocationViewModel(
            repository: LiveLocationRepository(
                roomID : roomID,
                service: locationService
            )
        )
    }

    /// Drops the cached conversation and every cached thread of one room.
    ///
    /// Call it after the screens of that room have shut themselves down, when the user has actually
    /// left rather than merely pushed something on top.
    func releaseRoom(_ roomID: String) {
        timelineProvider.release(roomID: roomID)
    }

    /// In app notification banners need the sync loop's notifications forwarded, and that
    /// registration is the one part of `start()` allowed to fail quietly: no banners is a far
    /// smaller problem than no session.
    private func startForwardingNotifications() async {
        do {
            try await notificationItemService.startObservingSyncNotifications()
        } catch {
            Log.notifications.error(
                "Sync notifications could not be forwarded: \(String(reflecting: error), privacy: .public)"
            )
        }
    }
}
