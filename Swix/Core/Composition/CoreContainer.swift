//
//  CoreContainer.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation


/// The root of the Core, and the one object the app itself has to own.
///
/// It holds what outlives every session, the keychain, the client and the session and login stacks,
/// and it owns the `UserSessionScope` that holds everything which does not. The scope is opened as
/// soon as the session turns authenticated and closed as soon as it stops being, so a view never
/// has to wonder whether the feature it needs has a client behind it: either `scope` is there and
/// everything in it is usable, or it is nil and there is nothing to show but the login.
///
/// One instance per process. Building a second one would hand the same store directories to a
/// second SDK client, and the store lock only lets one of them win.
@Observable
final class CoreContainer {

    /// Every stack of the live session, nil whenever no account is signed in.
    ///
    /// Views read this to reach a feature, and re-read it after a sign out: the object is replaced
    /// wholesale rather than emptied, so holding onto one across sessions keeps a dead client alive.
    private(set) var scope: UserSessionScope?

    /// Whether a stored account exists and is still being brought back.
    ///
    /// This is the first frame's question: true means "show the splash, the app is coming", and it
    /// goes false the moment the restore lands anywhere, so a failed restore falls through to the
    /// sign in instead of stranding the user on the splash.
    var hasStoredAccount: Bool {
        sessionRepository.hasStoredAccount
    }

    /// What a root view binds to in order to choose between the splash, the login and the app.
    @ObservationIgnored
    let sessionViewModel: SessionViewModel

    /// What the login screen binds to.
    @ObservationIgnored
    let loginViewModel: LoginViewModel

    @ObservationIgnored
    private let clientService: ClientService

    @ObservationIgnored
    private let sessionRepository: SessionRepository

    @ObservationIgnored
    private let authenticationRepository: AuthenticationRepository

    @ObservationIgnored
    private let stateChanges: AsyncStream<Void>

    @ObservationIgnored
    private let stateChangeContinuation: AsyncStream<Void>.Continuation

    @ObservationIgnored
    private var stateObservationTask: Task<Void, Never>?

    /// Assembles the session wide stack. Nothing is read from disk and nothing is sent yet: the
    /// keychain and the homeserver are only touched once `start()` runs.
    init() {
        TracingSetup.ensureInitialized()

        // One keychain instance serves both the SDK's own session writes and our persistence
        // service, because both have to agree on which item a session is stored under.
        let sessionKeychain = SessionKeychain()

        let clientService = ClientService(
            builderFactory: ClientBuilderFactory(sessionKeychain: sessionKeychain)
        )

        let persistenceService = SessionPersistenceService(sessionKeychain: sessionKeychain)

        let sessionRepository = SessionRepository(
            clientService     : clientService,
            persistenceService: persistenceService
        )

        let authenticationRepository = AuthenticationRepository(
            authenticationService: AuthenticationService(clientService: clientService),
            webAuthenticator     : OAuthWebAuthenticator(),
            sessionRepository    : sessionRepository,
            persistenceService   : persistenceService
        )

        self.clientService            = clientService
        self.sessionRepository        = sessionRepository
        self.authenticationRepository = authenticationRepository

        self.sessionViewModel = SessionViewModel(repository: sessionRepository)
        self.loginViewModel   = LoginViewModel(repository: authenticationRepository)

        (stateChanges, stateChangeContinuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .unbounded)
    }

    /// Restores the stored account, if there is one, and opens its scope.
    ///
    /// Safe to call more than once: the session restore is itself idempotent, and the state
    /// observation is only ever attached once.
    func start() async {
        observeSessionState()

        await sessionViewModel.restore()
        await synchronizeScope()
    }

    /// Signs the account out and erases its local data.
    ///
    /// The scope is closed before the account is, because every listener in it was registered on a
    /// client that `signOut()` is about to drop, and the SDK is happier releasing handles while the
    /// thing that issued them is still alive.
    func signOut() async {
        closeScope()

        await sessionViewModel.signOut()
    }

    /// Forwards the app's scene phase so sync follows the app into and out of the background.
    ///
    /// The call site maps SwiftUI's `ScenePhase` onto `AppScenePhase`; doing it there is what keeps
    /// the whole Core free of SwiftUI. Silently ignored while no session is open.
    func handle(scenePhase: AppScenePhase) {
        scope?.syncLifecycleController.handle(scenePhase: scenePhase)
    }

    /// Releases the scope, the session subscriptions and the state observation.
    ///
    /// The app never needs this, since the process dies with the container, but a test that builds
    /// a container per case does.
    func shutdown() {
        stateObservationTask?.cancel()
        stateObservationTask = nil

        closeScope()
        sessionRepository.shutdown()
    }

    /// Watches the session state for the transitions nothing on this object asked for: a token
    /// expiring mid session, a soft logout, a login completing inside the login screen.
    private func observeSessionState() {
        guard stateObservationTask == nil else {
            return
        }

        trackSessionState()

        stateObservationTask = Task { [weak self, changes = stateChanges] in
            for await _ in changes {
                guard let self else {
                    return
                }

                await synchronizeScope()
                trackSessionState()
            }
        }
    }

    /// Observation fires before the new value lands, so the change is only signalled here and acted
    /// on by the task above, which by then reads the state the session actually moved to.
    private func trackSessionState() {
        withObservationTracking {
            _ = sessionRepository.state
        } onChange: { [continuation = stateChangeContinuation] in
            continuation.yield()
        }
    }

    /// Makes the scope match the session: opens one, keeps the one that is already right, or closes
    /// it when there is no live account left.
    ///
    /// The account is compared rather than just its presence, so a session that merely refreshed
    /// keeps its listeners while a session replaced by another account gets a clean scope.
    private func synchronizeScope() async {
        guard sessionRepository.state.isAuthenticated,
              let userSession = sessionRepository.state.userSession else {
            closeScope()

            return
        }

        if let scope, scope.userSession.userID == userSession.userID {
            return
        }

        closeScope()

        let scope = UserSessionScope(
            userSession  : userSession,
            clientService: clientService
        )

        self.scope = scope

        await scope.start()
    }

    private func closeScope() {
        guard let scope else {
            return
        }

        scope.shutdown()

        self.scope = nil
    }
}
