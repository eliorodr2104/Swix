//
//  PresenceService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// The default `PresenceServiceProtocol`, wired on `Client`'s presence and status methods.
final class PresenceService: PresenceServiceProtocol {

    private let clientService: any ClientServiceProtocol

    init(clientService: any ClientServiceProtocol) {
        self.clientService = clientService
    }

    func setPresence(_ presence: PresenceState, immediate: Bool) async throws {
        let client = try activeClient()

        do {
            try await client.setPresence(presence: PresenceStateMapper.makeSDKPresenceState(from: presence), immediate: immediate)
        } catch {
            throw UsersFailure.sdk(SDKErrorInfo(error))
        }
    }

    func setUserStatus(_ status: UserStatusInfo) async throws {
        let client = try activeClient()

        do {
            try await client.setUserStatus(status: UserProfileMapper.makeSDKUserStatus(from: status))
        } catch {
            throw UsersFailure.sdk(SDKErrorInfo(error))
        }
    }

    func clearUserStatus() async throws {
        let client = try activeClient()

        do {
            try await client.clearUserStatus()
        } catch {
            throw UsersFailure.sdk(SDKErrorInfo(error))
        }
    }

    func isUserStatusSupported() async throws -> Bool {
        let client = try activeClient()

        do {
            return try await client.isUserStatusSupported()
        } catch {
            throw UsersFailure.sdk(SDKErrorInfo(error))
        }
    }

    private func activeClient() throws -> Client {
        guard let client = clientService.sdkClient else {
            throw UsersFailure.noActiveClient
        }

        return client
    }
}
