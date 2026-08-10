//
//  IgnoredUsersService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// The default `IgnoredUsersServiceProtocol`, wired on `Client`'s ignore list methods.
final class IgnoredUsersService: IgnoredUsersServiceProtocol {

    let ignoredUserIDsStream: AsyncStream<[String]>

    private let clientService: any ClientServiceProtocol

    private let ignoredUserIDsContinuation: AsyncStream<[String]>.Continuation

    private let subscriptions = SubscriptionBag()

    private var isObserving = false

    init(clientService: any ClientServiceProtocol) {
        self.clientService = clientService

        (ignoredUserIDsStream, ignoredUserIDsContinuation) = AsyncStream<[String]>.makeStream(bufferingPolicy: .unbounded)
    }

    func fetchIgnoredUserIDs() async throws -> [String] {
        let client = try activeClient()

        do {
            return try await client.ignoredUsers()
        } catch {
            throw UsersFailure.sdk(SDKErrorInfo(error))
        }
    }

    func ignore(userID: String) async throws {
        let client = try activeClient()

        do {
            try await client.ignoreUser(userId: userID)
        } catch {
            throw UsersFailure.sdk(SDKErrorInfo(error))
        }
    }

    func unignore(userID: String) async throws {
        let client = try activeClient()

        do {
            try await client.unignoreUser(userId: userID)
        } catch {
            throw UsersFailure.sdk(SDKErrorInfo(error))
        }
    }

    func startObservingIgnoredUsers() throws {
        guard !isObserving else {
            return
        }

        let client = try activeClient()
        let (stream, listener) = makeSDKStream(of: [String].self)

        subscriptions.retain(client.subscribeToIgnoredUsers(listener: listener))

        isObserving = true

        subscriptions.retain(Task { [ignoredUserIDsContinuation] in
            for await ids in stream {
                ignoredUserIDsContinuation.yield(ids)
            }
        })
    }

    func shutdown() {
        subscriptions.cancelAll()
        isObserving = false
    }

    private func activeClient() throws -> Client {
        guard let client = clientService.sdkClient else {
            throw UsersFailure.noActiveClient
        }

        return client
    }
}
