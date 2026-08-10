//
//  ProfileService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import MatrixRustSDK


/// The default `ProfileServiceProtocol`, wired on `Client`'s profile methods.
final class ProfileService: ProfileServiceProtocol {

    let ownProfileStream: AsyncStream<UserProfileInfo>

    private let clientService: any ClientServiceProtocol

    private let ownProfileContinuation: AsyncStream<UserProfileInfo>.Continuation

    private let subscriptions = SubscriptionBag()

    private var isObservingOwnProfile = false

    init(clientService: any ClientServiceProtocol) {
        self.clientService = clientService

        (ownProfileStream, ownProfileContinuation) = AsyncStream<UserProfileInfo>.makeStream(bufferingPolicy: .unbounded)
    }

    func fetchOwnProfile() async throws -> UserProfileInfo {
        let client = try activeClient()

        do {
            let ownUserID = try client.userId()

            return UserProfileMapper.makeUserProfileInfo(from: try await client.getProfile(userId: ownUserID))
        } catch {
            throw UsersFailure.sdk(SDKErrorInfo(error))
        }
    }

    func getProfile(userID: String) async throws -> UserProfileInfo {
        let client = try activeClient()

        do {
            return UserProfileMapper.makeUserProfileInfo(from: try await client.getProfile(userId: userID))
        } catch {
            throw UsersFailure.sdk(SDKErrorInfo(error))
        }
    }

    func setDisplayName(_ name: String) async throws {
        let client = try activeClient()

        do {
            try await client.setDisplayName(name: name)
        } catch {
            throw UsersFailure.sdk(SDKErrorInfo(error))
        }
    }

    func uploadAvatar(data: Data, mimeType: String) async throws {
        let client = try activeClient()

        do {
            try await client.uploadAvatar(mimeType: mimeType, data: data)
        } catch {
            throw UsersFailure.sdk(SDKErrorInfo(error))
        }
    }

    func removeAvatar() async throws {
        let client = try activeClient()

        do {
            try await client.removeAvatar()
        } catch {
            throw UsersFailure.sdk(SDKErrorInfo(error))
        }
    }

    func startObservingOwnProfile() throws {
        guard !isObservingOwnProfile else {
            return
        }

        let client = try activeClient()
        let (stream, listener) = makeSDKStream(of: UserProfile.self)

        do {
            subscriptions.retain(try client.subscribeToOwnProfile(listener: listener))
        } catch {
            throw UsersFailure.sdk(SDKErrorInfo(error))
        }

        isObservingOwnProfile = true

        subscriptions.retain(Task { [ownProfileContinuation] in
            for await profile in stream {
                ownProfileContinuation.yield(UserProfileMapper.makeUserProfileInfo(from: profile))
            }
        })
    }

    func shutdown() {
        subscriptions.cancelAll()
        isObservingOwnProfile = false
    }

    private func activeClient() throws -> Client {
        guard let client = clientService.sdkClient else {
            throw UsersFailure.noActiveClient
        }

        return client
    }
}
