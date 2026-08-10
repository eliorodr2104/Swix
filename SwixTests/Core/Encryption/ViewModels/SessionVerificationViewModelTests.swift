//
//  SessionVerificationViewModelTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("SessionVerificationViewModel")
struct SessionVerificationViewModelTests {

    @Test("A fresh view model reflects an idle, empty flow")
    func freshViewModelIsIdle() {
        let viewModel = Self.makeViewModel().viewModel

        #expect(viewModel.flowState == .idle)
        #expect(viewModel.emojis.isEmpty)
        #expect(viewModel.incomingRequest == nil)
        #expect(!viewModel.isBusy)
        #expect(!viewModel.isFinished)
        #expect(!viewModel.isVerified)
        #expect(!viewModel.showsEmojiComparison)
        #expect(!viewModel.showsIncomingRequest)
        #expect(viewModel.failure == nil)
    }

    @Test("beginVerification() moves the flow to requested, which reads as busy")
    func beginVerificationIsBusy() async {
        let (service, viewModel) = Self.makeViewModel()

        await viewModel.beginVerification()

        #expect(viewModel.flowState == .requested)
        #expect(viewModel.isBusy)
        #expect(viewModel.failure == nil)
        #expect(service.requestDeviceVerificationCallCount == 1)
    }

    @Test("The full happy path drives every derived property, ending verified and finished")
    func happyPathDrivesDerivedProperties() async {
        let (service, viewModel) = Self.makeViewModel()

        await viewModel.beginVerification()

        service.eventsContinuation.yield(.requestAccepted)
        await Eventually.isTrue { viewModel.flowState == .accepted }

        service.eventsContinuation.yield(.sasStarted)
        await Eventually.isTrue { viewModel.flowState == .sasStarted }

        let emojis = [EmojiPair(id: 0, symbol: "🐱", description: "Cat")]
        service.eventsContinuation.yield(.emojisReceived(emojis))
        await Eventually.isTrue { viewModel.showsEmojiComparison }

        #expect(viewModel.emojis == emojis)

        await viewModel.theyMatch()

        #expect(viewModel.isBusy)

        service.eventsContinuation.yield(.finished)
        await Eventually.isTrue { viewModel.isVerified }

        #expect(viewModel.isFinished)
        #expect(!viewModel.isBusy)
        #expect(viewModel.failure == nil)
    }

    @Test("theyDontMatch() cancels the flow, which reads as finished but not verified")
    func theyDontMatchCancelsTheFlow() async {
        let (service, viewModel) = await Self.makeViewModelShowingEmojis()

        await viewModel.theyDontMatch()

        #expect(viewModel.flowState == .cancelled)
        #expect(viewModel.isFinished)
        #expect(!viewModel.isVerified)
        #expect(service.declineCallCount == 1)
    }

    @Test("cancel() abandons an in-flight verification")
    func cancelAbandonsTheFlow() async {
        let (service, viewModel) = Self.makeViewModel()

        await viewModel.beginVerification()
        await viewModel.cancel()

        #expect(viewModel.flowState == .cancelled)
        #expect(service.cancelCallCount == 1)
    }

    @Test("An incoming request surfaces its sender and can be accepted")
    func incomingRequestSurfacesAndAccepts() async {
        let (service, viewModel) = Self.makeViewModel()

        await viewModel.beginVerification() // start()s the repository without racing an explicit start()

        service.eventsContinuation.yield(
            .requestReceived(
                senderID         : "@bob:example.org",
                flowID           : "flow-1",
                deviceID         : "DEVICE2",
                deviceDisplayName: "Bob's Phone"
            )
        )

        await Eventually.isTrue { viewModel.showsIncomingRequest }

        #expect(viewModel.incomingRequest?.senderID == "@bob:example.org")

        await viewModel.acceptIncomingRequest()

        #expect(service.acceptRequestCallCount == 1)
    }

    @Test("startOver() clears a finished flow and any failure back to idle")
    func startOverClearsFinishedFlow() async {
        let (service, viewModel) = await Self.makeViewModelShowingEmojis()

        service.eventsContinuation.yield(.finished)
        await Eventually.isTrue { viewModel.isVerified }

        viewModel.startOver()

        #expect(viewModel.flowState == .idle)
        #expect(viewModel.failure == nil)
    }

    @Test(
        "Every EncryptionFailure case titles the failure banner correctly",
        arguments: [
            (EncryptionFailure.noActiveClient, "No account to verify"),
            (EncryptionFailure.verificationUnavailable(await Fixtures.sdkErrorInfo()), "Verification is unavailable"),
            (EncryptionFailure.invalidRecoveryKey(await Fixtures.sdkErrorInfo()), "That key did not work"),
            (EncryptionFailure.recoveryFailed(await Fixtures.sdkErrorInfo()), "Recovery failed"),
            (EncryptionFailure.backupFailed(await Fixtures.sdkErrorInfo()), "Key backup failed"),
            (EncryptionFailure.unsupportedVerificationMethod, "Swix cannot show this comparison"),
            (EncryptionFailure.sdk(await Fixtures.sdkErrorInfo()), "Verification could not be completed")
        ]
    )
    func titleMapping(
        failure      : EncryptionFailure,
        expectedTitle: String
    ) async {

        let (service, viewModel) = Self.makeViewModel()
        service.requestDeviceVerificationError = failure

        await viewModel.beginVerification()

        #expect(viewModel.failure?.title == expectedTitle)
        #expect(viewModel.failure?.message == failure.message)
        #expect(viewModel.failure?.isRetryable == failure.isRetryable)
    }

    // MARK: Fixtures

    private static func makeViewModel() -> (service: MockSessionVerificationService, viewModel: SessionVerificationViewModel) {
        let service = MockSessionVerificationService()
        let repository = SessionVerificationRepository(service: service)
        let viewModel = SessionVerificationViewModel(repository: repository)

        return (service, viewModel)
    }

    /// A view model already showing emojis, reached through the same initiator path a real screen
    /// would go through.
    private static func makeViewModelShowingEmojis() async -> (MockSessionVerificationService, SessionVerificationViewModel) {
        let (service, viewModel) = Self.makeViewModel()

        await viewModel.beginVerification()

        service.eventsContinuation.yield(.requestAccepted)
        await Eventually.isTrue { viewModel.flowState == .accepted }

        service.eventsContinuation.yield(.sasStarted)
        await Eventually.isTrue { viewModel.flowState == .sasStarted }

        let emojis = [EmojiPair(id: 0, symbol: "🐱", description: "Cat")]
        service.eventsContinuation.yield(.emojisReceived(emojis))
        await Eventually.isTrue { viewModel.showsEmojiComparison }

        return (service, viewModel)
    }
}
