//
//  PusherService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import os


/// The default `PusherServiceProtocol`, built on `Client.setPusher`/`Client.deletePusher`.
final class PusherService: PusherServiceProtocol {

    private let clientService: any ClientServiceProtocol

    init(clientService: any ClientServiceProtocol) {
        self.clientService = clientService
    }

    func registerPusher(_ configuration: PusherConfiguration) async throws {
        guard let client = clientService.sdkClient else {
            throw NotificationsFailure.noActiveClient
        }

        do {
            try await client.setPusher(
                identifiers      : PusherConfigurationMapper.makeIdentifiers(from: configuration),
                kind             : PusherConfigurationMapper.makeKind(from: configuration),
                appDisplayName   : configuration.appDisplayName,
                deviceDisplayName: configuration.deviceDisplayName,
                profileTag       : configuration.profileTag,
                lang             : configuration.language,
                append           : configuration.appendsToExistingPushers
            )

            Log.notifications.notice("Pusher registered for app \(configuration.appID, privacy: .public)")
        } catch {
            throw NotificationsFailure.pusherRegistrationFailed(SDKErrorInfo(error))
        }
    }

    func unregisterPusher(_ configuration: PusherConfiguration) async throws {
        guard let client = clientService.sdkClient else {
            throw NotificationsFailure.noActiveClient
        }

        do {
            try await client.deletePusher(identifiers: PusherConfigurationMapper.makeIdentifiers(from: configuration))

            Log.notifications.notice("Pusher removed for app \(configuration.appID, privacy: .public)")
        } catch {
            throw NotificationsFailure.pusherRegistrationFailed(SDKErrorInfo(error))
        }
    }
}
