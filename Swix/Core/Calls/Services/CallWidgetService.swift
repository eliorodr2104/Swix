//
//  CallWidgetService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import MatrixRustSDK
import os

/// The default `CallWidgetServiceProtocol`, built on the SDK's virtual Element Call widget.
final class CallWidgetService: CallWidgetServiceProtocol {

    let callEndedEvents: AsyncStream<Void>

    private let roomProvider: any RoomProviding

    private let clientService: any ClientServiceProtocol

    private let callEndedContinuation: AsyncStream<Void>.Continuation

    private var activeChannel: CallWidgetChannel?

    init(
        roomProvider : any RoomProviding,
        clientService: any ClientServiceProtocol
    ) {
        self.roomProvider  = roomProvider
        self.clientService = clientService

        (callEndedEvents, callEndedContinuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .unbounded)
    }

    func hasActiveCall(inRoom roomID: String) -> Bool {
        (try? roomProvider.room(withId: roomID))?.hasActiveRoomCall() ?? false
    }

    func prepareCall(
        roomID       : String,
        configuration: CallWidgetConfiguration
    ) async throws -> CallSession {
    
        activeChannel?.stop()
        activeChannel = nil

        guard let userID = clientService.userID,
              let deviceID = clientService.deviceID else {
            throw CallFailure.noActiveClient
        }

        let room: Room
        do {
            room = try roomProvider.room(withId: roomID)
            
        } catch {
            throw CallFailure.roomUnavailable(SDKErrorInfo(error))
        }

        do {
            let widgetID = UUID().uuidString
            
            let properties = CallWidgetSettingsMapper.makeWidgetProperties(
                configuration: configuration,
                widgetID     : widgetID
            )
            
            let widgetConfig = CallWidgetSettingsMapper.makeWidgetConfig(
                configuration: configuration
            )
            
            let settings = try newVirtualElementCallWidget(
                props : properties,
                config: widgetConfig
            )

            let clientProperties = ClientProperties(
                clientId   : MatrixConfiguration.oauthRedirectScheme,
                languageTag: Locale.preferredLanguages.first,
                theme      : nil
            )
            
            let rawURL = try await generateWebviewUrl(
                widgetSettings: settings,
                room          : room,
                props         : clientProperties
            )

            guard let widgetURL = URL(string: rawURL) else {
                throw CallFailure.widgetSetupFailed(
                    SDKErrorInfo(
                        kind   : .unknown,
                        message: "The SDK returned a webview URL that could not be parsed",
                        details: rawURL
                    )
                )
            }

            let driverAndHandle = try makeWidgetDriver(settings: settings)
            let capabilitiesProvider = SDKWidgetCapabilitiesProvider(
                ownUserID  : userID,
                ownDeviceID: deviceID
            )
            
            let channel = CallWidgetChannel(
                driver              : driverAndHandle.driver,
                handle              : driverAndHandle.handle,
                room                : room,
                capabilitiesProvider: capabilitiesProvider
            )

            channel.onDriverStopped = { [weak self] in
                self?.activeChannel = nil
                Log.calls.notice("Widget driver for room \(roomID, privacy: .public) stopped on its own")
                self?.callEndedContinuation.yield()
            }

            channel.start()
            activeChannel = channel

            return CallSession(
                roomID           : roomID,
                widgetURL        : widgetURL,
                messagesToWebView: channel.messagesToWebView,
                postMessage: { [weak channel] message in
                    await channel?.post(fromWebView: message) ?? false
                }
            )
            
        } catch let failure as CallFailure {
            throw failure
            
        } catch {
            throw CallFailure.widgetSetupFailed(SDKErrorInfo(error))
        }
    }

    func endCall() async {
        activeChannel?.stop()
        activeChannel = nil
    }
}
