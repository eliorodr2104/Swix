//
//  SessionVerificationService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import os


/// The default `SessionVerificationServiceProtocol`, built on
/// `Client.getSessionVerificationController()`.
final class SessionVerificationService: SessionVerificationServiceProtocol {

    let events: AsyncStream<VerificationEvent>

    private let clientService: any ClientServiceProtocol

    private let continuation: AsyncStream<VerificationEvent>.Continuation

    private let subscriptions = SubscriptionBag()

    private var controller: SessionVerificationController?

    // setDelegate hands the listener to Rust, which owns it for as long as the delegate is set.
    // Holding it here too keeps the stream alive if the controller is ever replaced.
    private var delegateListener: SDKListener<SDKVerificationEvent>?

    init(clientService: any ClientServiceProtocol) {
        self.clientService = clientService

        (events, continuation) = AsyncStream<VerificationEvent>.makeStream(bufferingPolicy: .unbounded)
    }

    func start() async throws {
        guard controller == nil else {
            return
        }

        guard let client = clientService.sdkClient else {
            throw EncryptionFailure.noActiveClient
        }

        let controller: SessionVerificationController

        do {
            controller = try await client.getSessionVerificationController()
            
        } catch {
            throw EncryptionFailure.verificationUnavailable(SDKErrorInfo(error))
        }

        let (rawEvents, listener) = makeSDKStream(of: SDKVerificationEvent.self)

        controller.setDelegate(delegate: listener)

        self.controller = controller
        self.delegateListener = listener

        subscriptions.retain(
            Task { [continuation] in
                for await event in rawEvents {
                    continuation.yield(Self.makeEvent(from: event))
                }
            }
        )

        Log.encryption.notice("Session verification controller ready")
    }

    func requestDeviceVerification() async throws {
        try await perform { try await $0.requestDeviceVerification() }
    }

    func requestUserVerification(userID: String) async throws {
        try await perform { try await $0.requestUserVerification(userId: userID) }
    }

    func acknowledgeRequest(senderID: String, flowID: String) async throws {
        try await perform {
            try await $0.acknowledgeVerificationRequest(
                senderId: senderID,
                flowId  : flowID
            )
        }
    }

    func acceptRequest() async throws {
        try await perform { try await $0.acceptVerificationRequest() }
    }

    func startSas() async throws {
        try await perform { try await $0.startSasVerification() }
    }

    func approve() async throws {
        try await perform { try await $0.approveVerification() }
    }

    func decline() async throws {
        try await perform { try await $0.declineVerification() }
    }

    func cancel() async throws {
        try await perform { try await $0.cancelVerification() }
    }

    func shutdown() {
        controller?.setDelegate(delegate: nil)
        subscriptions.cancelAll()

        controller = nil
        delegateListener = nil
    }

    /// Every intent is the same shape: make sure the controller exists, run one call on it, and
    /// normalize whatever the SDK raises into this feature's vocabulary.
    private func perform(
        _ operation: (SessionVerificationController) async throws -> Void
    ) async throws {
        
        try await start()

        guard let controller else {
            throw EncryptionFailure.noActiveClient
        }

        do {
            try await operation(controller)
            
        } catch { throw EncryptionFailure.sdk(SDKErrorInfo(error)) }
    }

    private static func makeEvent(
        from event: SDKVerificationEvent
    ) -> VerificationEvent {
    
        switch event {
            case .receivedRequest(let details):
                .requestReceived(
                    senderID         : details.senderProfile.userId,
                    flowID           : details.flowId,
                    deviceID         : details.deviceId,
                    deviceDisplayName: details.deviceDisplayName
                )

            case .acceptedRequest: .requestAccepted
            case .startedSas     : .sasStarted

            case .receivedData(let data):
                VerificationEmojiMapper.makeEmojiPairs(from: data).map {
                    VerificationEvent.emojisReceived($0)
                } ?? .unsupportedDataReceived

            case .failed   : .failed
            case .cancelled: .cancelled
            case .finished : .finished
        }
    }
}
