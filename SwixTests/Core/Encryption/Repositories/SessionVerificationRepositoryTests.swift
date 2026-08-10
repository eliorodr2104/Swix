//
//  SessionVerificationRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("SessionVerificationRepository")
struct SessionVerificationRepositoryTests {

    // MARK: Happy path, as the initiator

    @Test("The full initiator happy path runs from requested through to verified")
    func initiatorHappyPath() async {
        let service = MockSessionVerificationService()
        let repository = SessionVerificationRepository(service: service)

        await repository.requestVerification()

        #expect(repository.flowState == .requested)
        #expect(service.requestDeviceVerificationCallCount == 1)

        service.eventsContinuation.yield(.requestAccepted)
        await Eventually.isTrue { repository.flowState == .accepted }

        // Only the initiator moves an accepted request into SAS.
        await Eventually.isTrue { service.startSasCallCount == 1 }
        #expect(repository.flowState == .accepted)

        service.eventsContinuation.yield(.sasStarted)
        await Eventually.isTrue { repository.flowState == .sasStarted }

        let emojis = [EmojiPair(id: 0, symbol: "🐱", description: "Cat")]
        service.eventsContinuation.yield(.emojisReceived(emojis))
        await Eventually.isTrue { repository.flowState == .showingEmojis(emojis) }

        await repository.approve()

        #expect(repository.flowState == .approving)
        #expect(service.approveCallCount == 1)

        service.eventsContinuation.yield(.finished)
        await Eventually.isTrue { repository.flowState == .verified }

        #expect(repository.flowState == .verified)
        #expect(repository.failure == nil)
    }

    @Test("requestVerification(ofUser:) forwards the target user id")
    func requestUserVerificationForwardsUserID() async {
        let service = MockSessionVerificationService()
        let repository = SessionVerificationRepository(service: service)

        await repository.requestVerification(ofUser: "@bob:example.org")

        #expect(repository.flowState == .requested)
        #expect(service.requestUserVerificationUserIDs == ["@bob:example.org"])
    }

    // MARK: Happy path, as the responder

    @Test("An incoming request is auto acknowledged and waits for the user before starting SAS")
    func responderAcknowledgesAndWaits() async {
        let service = MockSessionVerificationService()
        let repository = SessionVerificationRepository(service: service)

        await repository.start()

        service.eventsContinuation.yield(
            .requestReceived(
                senderID         : "@bob:example.org",
                flowID           : "flow-1",
                deviceID         : "DEVICE2",
                deviceDisplayName: "Bob's Phone"
            )
        )

        await Eventually.isTrue { repository.flowState == .waitingForAcceptance }

        #expect(service.acknowledgeRequestArgs.count == 1)
        #expect(service.acknowledgeRequestArgs.first?.senderID == "@bob:example.org")
        #expect(service.acknowledgeRequestArgs.first?.flowID == "flow-1")
        #expect(repository.incomingRequest == IncomingVerificationRequest(
            senderID         : "@bob:example.org",
            flowID           : "flow-1",
            deviceID         : "DEVICE2",
            deviceDisplayName: "Bob's Phone"
        ))

        await repository.acceptIncomingRequest()

        #expect(service.acceptRequestCallCount == 1)

        service.eventsContinuation.yield(.requestAccepted)
        await Eventually.isTrue { repository.flowState == .accepted }

        // The responder never calls startSas: only the initiator does.
        #expect(service.startSasCallCount == 0)

        service.eventsContinuation.yield(.sasStarted)
        await Eventually.isTrue { repository.flowState == .sasStarted }
    }

    // MARK: Cancellation branches

    @Test("Declining the emoji comparison cancels the flow")
    func decliningEmojisCancelsTheFlow() async {
        let (service, repository) = await Self.makeRepositoryShowingEmojis()

        await repository.decline()

        #expect(service.declineCallCount == 1)
        #expect(repository.flowState == .cancelled)
        #expect(repository.failure == nil)
    }

    @Test("Cancelling a non-idle, non-terminal flow calls the service and lands on cancelled")
    func cancelANonTerminalFlowCallsTheService() async {
        let service = MockSessionVerificationService()
        let repository = SessionVerificationRepository(service: service)

        await repository.requestVerification()
        await repository.cancel()

        #expect(service.cancelCallCount == 1)
        #expect(repository.flowState == .cancelled)
    }

    @Test("Cancelling an idle flow resets locally without calling the service")
    func cancelAnIdleFlowIsLocalOnly() async {
        let service = MockSessionVerificationService()
        let repository = SessionVerificationRepository(service: service)

        await repository.cancel()

        #expect(service.cancelCallCount == 0)
        #expect(repository.flowState == .idle)
    }

    @Test("Cancelling an already terminal flow resets locally without calling the service")
    func cancelATerminalFlowIsLocalOnly() async {
        let (service, repository) = await Self.makeRepositoryShowingEmojis()

        service.eventsContinuation.yield(.finished)
        await Eventually.isTrue { repository.flowState == .verified }

        await repository.cancel()

        #expect(service.cancelCallCount == 0)
        #expect(repository.flowState == .idle)
    }

    @Test("The other side cancelling is reported as .cancelled directly")
    func remoteCancelIsReported() async {
        let service = MockSessionVerificationService()
        let repository = SessionVerificationRepository(service: service)

        await repository.requestVerification()

        service.eventsContinuation.yield(.cancelled)
        await Eventually.isTrue { repository.flowState == .cancelled }
    }

    // MARK: Failure branches

    @Test("A failing start() records the failure and never begins observing")
    func startFailureRecordsFailure() async {
        let service = MockSessionVerificationService()
        service.startError = EncryptionFailure.verificationUnavailable(Fixtures.sdkErrorInfo())

        let repository = SessionVerificationRepository(service: service)

        await repository.requestVerification()

        #expect(repository.flowState == .idle)
        #expect(repository.failure != nil)
        #expect(service.requestDeviceVerificationCallCount == 0)
    }

    @Test("A failing intent records the failure and moves the flow to failed")
    func failingIntentMovesToFailed() async {
        let service = MockSessionVerificationService()
        service.acceptRequestError = EncryptionFailure.sdk(Fixtures.sdkErrorInfo())

        let repository = SessionVerificationRepository(service: service)

        await repository.start()

        service.eventsContinuation.yield(
            .requestReceived(
                senderID         : "@bob:example.org",
                flowID           : "flow-1",
                deviceID         : "DEVICE2",
                deviceDisplayName: nil
            )
        )

        await Eventually.isTrue { repository.flowState == .waitingForAcceptance }

        await repository.acceptIncomingRequest()

        #expect(repository.flowState == .failed)

        guard case .sdk = repository.failure else {
            Issue.record("Expected .sdk, got \(String(describing: repository.failure))")
            return
        }
    }

    @Test("Declining fails when the service call itself fails, landing on failed rather than cancelled")
    func decliningFailureLandsOnFailed() async {
        let (service, repository) = await Self.makeRepositoryShowingEmojis()
        service.declineError = EncryptionFailure.sdk(Fixtures.sdkErrorInfo())

        await repository.decline()

        #expect(repository.flowState == .failed)
    }

    @Test("An acknowledgement that fails moves straight to failed, skipping waitingForAcceptance")
    func acknowledgeFailureSkipsWaiting() async {
        let service = MockSessionVerificationService()
        service.acknowledgeRequestError = EncryptionFailure.sdk(Fixtures.sdkErrorInfo())

        let repository = SessionVerificationRepository(service: service)
        await repository.start()

        service.eventsContinuation.yield(
            .requestReceived(
                senderID         : "@bob:example.org",
                flowID           : "flow-1",
                deviceID         : "DEVICE2",
                deviceDisplayName: nil
            )
        )

        await Eventually.isTrue { repository.flowState == .failed }

        #expect(repository.flowState == .failed)
    }

    @Test("Decimal SAS is unsupported: the flow cancels itself and fails")
    func unsupportedDataFailsTheFlow() async {
        let service = MockSessionVerificationService()
        let repository = SessionVerificationRepository(service: service)

        await repository.requestVerification()

        service.eventsContinuation.yield(.unsupportedDataReceived)

        await Eventually.isTrue { repository.flowState == .failed }

        #expect(service.cancelCallCount == 1)

        guard case .unsupportedVerificationMethod = repository.failure else {
            Issue.record("Expected .unsupportedVerificationMethod, got \(String(describing: repository.failure))")
            return
        }
    }

    @Test("A .failed event is reported as .failed directly")
    func failedEventIsReported() async {
        let service = MockSessionVerificationService()
        let repository = SessionVerificationRepository(service: service)

        await repository.requestVerification()

        service.eventsContinuation.yield(.failed)
        await Eventually.isTrue { repository.flowState == .failed }
    }

    // MARK: Guard clauses

    @Test("approve() is a no-op unless the flow is showing emojis")
    func approveIsNoOpOutsideShowingEmojis() async {
        let service = MockSessionVerificationService()
        let repository = SessionVerificationRepository(service: service)

        await repository.approve()

        #expect(service.approveCallCount == 0)
        #expect(repository.flowState == .idle)
    }

    @Test("acceptIncomingRequest() is a no-op unless waiting for acceptance")
    func acceptIsNoOpOutsideWaiting() async {
        let service = MockSessionVerificationService()
        let repository = SessionVerificationRepository(service: service)

        await repository.acceptIncomingRequest()

        #expect(service.acceptRequestCallCount == 0)
    }

    // MARK: reset()

    @Test("reset() returns a terminal flow to idle")
    func resetReturnsTerminalFlowToIdle() async {
        let (service, repository) = await Self.makeRepositoryShowingEmojis()

        service.eventsContinuation.yield(.finished)
        await Eventually.isTrue { repository.flowState == .verified }

        repository.reset()

        #expect(repository.flowState == .idle)
        #expect(repository.incomingRequest == nil)
        #expect(repository.failure == nil)
    }

    @Test("reset() does nothing to a flow that is still in progress")
    func resetIsNoOpMidFlow() async {
        let service = MockSessionVerificationService()
        let repository = SessionVerificationRepository(service: service)

        await repository.requestVerification()
        repository.reset()

        #expect(repository.flowState == .requested)
    }

    // MARK: stop()

    @Test("stop() releases the listener and allows a later restart")
    func stopReleasesListenerAndAllowsRestart() async {
        let service = MockSessionVerificationService()
        let repository = SessionVerificationRepository(service: service)

        await repository.start()
        repository.stop()

        #expect(service.shutdownCallCount == 1)

        await repository.start()

        #expect(service.startCallCount == 2)
    }

    // MARK: Fixtures

    /// A repository already sitting on `.showingEmojis`, reached the same way a real initiator
    /// would: requested, accepted, SAS started, emojis received.
    private static func makeRepositoryShowingEmojis() async -> (MockSessionVerificationService, SessionVerificationRepository) {
        let service = MockSessionVerificationService()
        let repository = SessionVerificationRepository(service: service)

        await repository.requestVerification()

        service.eventsContinuation.yield(.requestAccepted)
        await Eventually.isTrue { repository.flowState == .accepted }

        service.eventsContinuation.yield(.sasStarted)
        await Eventually.isTrue { repository.flowState == .sasStarted }

        let emojis = [EmojiPair(id: 0, symbol: "🐱", description: "Cat")]
        service.eventsContinuation.yield(.emojisReceived(emojis))
        await Eventually.isTrue { repository.flowState == .showingEmojis(emojis) }

        return (service, repository)
    }
}
