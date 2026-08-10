//
//  SessionVerificationRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation
import os

/// The state machine of one interactive verification, and the only writer of `flowState`.
///
/// Both directions of the flow converge on the same states: the difference is who calls
/// `startSasVerification`, which is why the initiator is remembered.
@Observable
final class SessionVerificationRepository {

    /// Where the flow stands right now. Views observe this through a view model.
    private(set) var flowState: VerificationFlowState = .idle

    /// The device that asked to verify this session, nil unless a request came in.
    private(set) var incomingRequest: IncomingVerificationRequest?

    /// The last failure an intent raised, kept until the next attempt clears it.
    private(set) var failure: EncryptionFailure?

    @ObservationIgnored
    private let service: any SessionVerificationServiceProtocol

    @ObservationIgnored
    private let subscriptions = SubscriptionBag()

    @ObservationIgnored
    private var isObserving = false

    // Only the side that asked for the verification may move the request into SAS. If both sides
    // start it the homeserver sees two competing flows and cancels them.
    @ObservationIgnored
    private var isInitiator = false

    init(service: any SessionVerificationServiceProtocol) {
        self.service = service
    }

    /// Obtains the controller and starts listening. Safe to call more than once.
    func start() async {
        guard !isObserving else {
            return
        }

        do {
            try await service.start()
            
        } catch {
            record(error)
            return
        }

        isObserving = true
        observeEvents()
    }

    /// Asks the account's other sessions to verify this device.
    func requestVerification() async {
        await start()

        guard isObserving else {
            return
        }

        failure         = nil
        isInitiator     = true
        incomingRequest = nil
        flowState       = .requested

        await run { try await self.service.requestDeviceVerification() }
    }

    /// Asks another user to verify their identity against ours.
    func requestVerification(ofUser userID: String) async {
        await start()

        guard isObserving else {
            return
        }

        failure         = nil
        isInitiator     = true
        incomingRequest = nil
        flowState       = .requested

        await run { try await self.service.requestUserVerification(userID: userID) }
    }

    /// Accepts the request another session sent, which is what unlocks the SAS exchange.
    func acceptIncomingRequest() async {
        guard flowState == .waitingForAcceptance else {
            return
        }

        await run { try await self.service.acceptRequest() }
    }

    /// Confirms that the emojis on the two screens are the same.
    func approve() async {
        guard case .showingEmojis = flowState else {
            return
        }

        flowState = .approving

        await run { try await self.service.approve() }
    }

    /// Reports that the emojis differ, which tells the other side something is wrong.
    func decline() async {
        guard case .showingEmojis = flowState else {
            return
        }

        failure = nil

        await run { try await self.service.decline() }

        if failure == nil {
            flowState = .cancelled
        }
    }

    /// Abandons the flow, whether the user asked for it or simply left the screen.
    func cancel() async {
        guard !flowState.isTerminal, flowState != .idle else {
            reset()

            return
        }

        failure = nil

        await run { try await self.service.cancel() }

        if failure == nil {
            flowState = .cancelled
        }
    }

    /// Returns a finished flow to its starting point so the user can try again.
    func reset() {
        guard flowState.isTerminal || flowState == .idle else {
            return
        }

        flowState       = .idle
        incomingRequest = nil
        isInitiator     = false
        failure         = nil
    }

    /// Releases every subscription this repository and its service own. Called once, by the scope
    /// that created them, when the session ends.
    func stop() {
        subscriptions.cancelAll()
        service.shutdown()

        isObserving = false
    }

    private func observeEvents() {
        subscriptions.retain(
            Task { [weak self, events = service.events] in
                for await event in events {
                    guard let self else {
                        return
                    }

                    await handle(event)
                }
            }
        )
    }

    private func handle(_ event: VerificationEvent) async {
        switch event {
            case .requestReceived(
                let senderID,
                let flowID,
                let deviceID,
                let deviceDisplayName
            ):
                await handleIncomingRequest(
                    senderID         : senderID,
                    flowID           : flowID,
                    deviceID         : deviceID,
                    deviceDisplayName: deviceDisplayName
                )

            case .requestAccepted           : await handleRequestAccepted()
            case .sasStarted                : flowState = .sasStarted
            case .emojisReceived(let emojis): flowState = .showingEmojis(emojis)
            case .unsupportedDataReceived   : await handleUnsupportedData()
            case .failed                    : flowState = .failed
            case .cancelled                 : flowState = .cancelled
            case .finished                  : flowState = .verified
        }
    }

    /// The SDK reports nothing further about a request until it has been acknowledged, so the
    /// acknowledgement is automatic and only the acceptance is left to the user.
    private func handleIncomingRequest(
        senderID         : String,
        flowID           : String,
        deviceID         : String,
        deviceDisplayName: String?
    ) async {
        failure     = nil
        isInitiator = false
        incomingRequest = IncomingVerificationRequest(
            senderID         : senderID,
            flowID           : flowID,
            deviceID         : deviceID,
            deviceDisplayName: deviceDisplayName
        )

        await run {
            try await self.service.acknowledgeRequest(
                senderID: senderID,
                flowID  : flowID
            )
        }

        guard failure == nil else {
            flowState = .failed

            return
        }

        flowState = .waitingForAcceptance
    }

    private func handleRequestAccepted() async {
        flowState = .accepted

        guard isInitiator else {
            return
        }

        await run { try await self.service.startSas() }
    }

    private func handleUnsupportedData() async {
        failure = .unsupportedVerificationMethod

        await run { try await self.service.cancel() }

        flowState = .failed
    }

    /// Runs one intent and turns any failure into both a recorded error and a failed flow, so no
    /// branch of the state machine can leave the screen spinning.
    private func run(_ intent: () async throws -> Void) async {
        do {
            try await intent()
            
        } catch {
            record(error)
            flowState = .failed
        }
    }

    private func record(_ error: any Error) {
        Log.encryption.error("Verification step failed: \(String(reflecting: error), privacy: .public)")

        failure = EncryptionFailure.wrapping(error)
    }
}
