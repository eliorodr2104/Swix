//
//  ClientService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import os


/// The default `ClientServiceProtocol`, wired on the SDK `ClientBuilder`.
final class ClientService: ClientServiceProtocol {

    let sessionEvents: AsyncStream<SessionEvent>

    private(set) var sdkClient: Client?

    private(set) var storeIdentity: SessionStoreIdentity?

    private let builderFactory: any ClientBuilderFactoryProtocol

    private let eventContinuation: AsyncStream<SessionEvent>.Continuation

    private let subscriptions = SubscriptionBag()

    // The bridge listener has to outlive the registration call: the stream it feeds ends as soon
    // as the last reference to it goes away.
    private var clientEventListener: SDKListener<SDKClientEvent>?

    // Only a store that was minted for a login attempt may be deleted when that attempt is
    // abandoned, never the stores of an account that already exists.
    private var isStoreProvisional = false

    init(builderFactory: any ClientBuilderFactoryProtocol) {
        self.builderFactory = builderFactory

        let (stream, continuation) = AsyncStream<SessionEvent>.makeStream(bufferingPolicy: .unbounded)

        sessionEvents     = stream
        eventContinuation = continuation
    }

    var currentSession: UserSession? {
        guard let persisted = try? session() else {
            return nil
        }

        return PersistedSessionMapper.makeUserSession(from: persisted)
    }

    var userID: String? {
        guard let sdkClient else {
            return nil
        }

        return try? sdkClient.userId()
    }

    var deviceID: String? {
        guard let sdkClient else {
            return nil
        }

        return try? sdkClient.deviceId()
    }

    @discardableResult
    func makeClient(homeserver: String) async throws -> Client {
        let provisionalIdentity = SessionStoreIdentity.makeProvisional()

        do {
            let client = try await makeClient(
                homeserver   : homeserver,
                storeIdentity: provisionalIdentity
            )

            isStoreProvisional = true

            return client
        } catch {
            SessionDirectories.deleteAll(for: provisionalIdentity.directoryIdentifier)

            throw error
        }
    }

    @discardableResult
    func makeClient(
        homeserver   : String,
        storeIdentity: SessionStoreIdentity
    ) async throws -> Client {
        discard()

        do {
            let builder = try builderFactory.makeBuilder(
                serverNameOrHomeserverURL: homeserver,
                storeIdentity            : storeIdentity
            )

            let client = try await builder.build()

            adopt(
                client,
                storeIdentity: storeIdentity
            )

            return client
        } catch {
            throw SessionFailure.sdk(SDKErrorInfo(error))
        }
    }

    @discardableResult
    func restore(
        _ persisted  : PersistedSession,
        storeIdentity: SessionStoreIdentity
    ) async throws -> UserSession {
        discard()

        do {
            let builder = try builderFactory.makeBuilder(
                homeserverURL: persisted.homeserverURL,
                storeIdentity: storeIdentity
            )

            let client = try await builder.build()

            try await client.restoreSession(session: PersistedSessionMapper.makeSession(from: persisted))

            adopt(
                client,
                storeIdentity: storeIdentity
            )

            return PersistedSessionMapper.makeUserSession(from: persisted)
        } catch {
            throw SessionFailure.restoreFailed(SDKErrorInfo(error))
        }
    }

    func session() throws -> PersistedSession {
        guard let sdkClient else {
            throw SessionFailure.noActiveClient
        }

        do {
            return PersistedSessionMapper.makePersistedSession(from: try sdkClient.session())
        } catch {
            throw SessionFailure.sdk(SDKErrorInfo(error))
        }
    }

    /// Signing out without a live client is not an error: a soft logout already dropped it, and
    /// there is nothing left to tell the homeserver.
    func logout() async throws {
        guard let sdkClient else {
            return
        }

        do {
            try await sdkClient.logout()
        } catch {
            throw SessionFailure.logoutFailed(SDKErrorInfo(error))
        }

        discard()
    }

    func discard() {
        subscriptions.cancelAll()

        clientEventListener = nil
        storeIdentity       = nil
        isStoreProvisional  = false
        sdkClient           = nil
    }

    func abandonPendingClient() {
        let abandonedIdentity = isStoreProvisional ? storeIdentity : nil

        discard()

        guard let abandonedIdentity else {
            return
        }

        SessionDirectories.deleteAll(for: abandonedIdentity.directoryIdentifier)
    }

    private func adopt(_ client: Client, storeIdentity: SessionStoreIdentity) {
        sdkClient          = client
        self.storeIdentity = storeIdentity

        observeClientEvents(of: client)
    }

    private func observeClientEvents(of client: Client) {
        let (stream, listener) = makeSDKStream(of: SDKClientEvent.self)

        do {
            if let handle = try client.setDelegate(delegate: listener) {
                subscriptions.retain(handle)
            }
        } catch {
            Log.session.error("Could not observe client events: \(String(reflecting: error), privacy: .public)")

            return
        }

        clientEventListener = listener

        subscriptions.retain(Task { [weak self] in
            for await event in stream {
                self?.forward(event)
            }
        })
    }

    private func forward(_ event: SDKClientEvent) {
        switch event {
            case .authError(let isSoftLogout):
                Log.session.notice("The homeserver rejected the token, soft logout: \(isSoftLogout, privacy: .public)")

                eventContinuation.yield(.authenticationExpired(isSoftLogout: isSoftLogout))

            case .backgroundTaskError(let taskName, let reason):
                eventContinuation.yield(
                    .backgroundTaskFailed(
                        taskName: taskName,
                        reason  : Self.describe(reason)
                    )
                )
        }
    }

    private static func describe(
        _ reason: BackgroundTaskFailureReason
    ) -> String {
        switch reason {
            case .panic(let message, _): message ?? "the task panicked"
            case .error(let error): error
            case .earlyTermination: "the task ended before it was supposed to"
        }
    }
}
