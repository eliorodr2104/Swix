//
//  SessionVerificationViewModel.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation

/// Everything the device verification screen binds to: where the flow stands, the emojis to
/// compare, and the three decisions the user can make.
@Observable
final class SessionVerificationViewModel {

    /// The failure to present. Views clear it by setting it back to nil.
    var failure: UserFacingFailure?

    @ObservationIgnored
    private let repository: SessionVerificationRepository

    init(repository: SessionVerificationRepository) {
        self.repository = repository
    }

    /// Where the flow stands, which is the only thing the screen switches on.
    var flowState: VerificationFlowState {
        repository.flowState
    }

    /// The emojis to compare, empty unless the flow is waiting on the user's answer.
    var emojis: [EmojiPair] {
        repository.flowState.emojis
    }

    /// The device that asked to verify this session, nil unless a request came in.
    var incomingRequest: IncomingVerificationRequest? {
        repository.incomingRequest
    }

    /// Whether the flow is waiting on the network, which is what shows the spinner.
    var isBusy: Bool {
        repository.flowState.isBusy
    }

    /// Whether the flow reached an outcome and the screen should offer to start over or close.
    var isFinished: Bool {
        repository.flowState.isTerminal
    }

    /// Whether this device ended up verified.
    var isVerified: Bool {
        repository.flowState == .verified
    }

    /// Whether the two comparison buttons belong on screen.
    var showsEmojiComparison: Bool {
        if case .showingEmojis = repository.flowState {
            return true
        }

        return false
    }

    /// Whether an incoming request is waiting for the user to accept it.
    var showsIncomingRequest: Bool {
        repository.flowState == .waitingForAcceptance
    }

    /// Asks the account's other sessions to verify this device.
    func beginVerification() async {
        await repository.requestVerification()

        updateFailure()
    }

    /// Accepts the request another session sent.
    func acceptIncomingRequest() async {
        await repository.acceptIncomingRequest()

        updateFailure()
    }

    /// The user says the emojis are identical on both screens.
    func theyMatch() async {
        await repository.approve()

        updateFailure()
    }

    /// The user says the emojis differ, which ends the flow as a mismatch.
    func theyDontMatch() async {
        await repository.decline()

        updateFailure()
    }

    /// Abandons the flow, typically because the screen is being dismissed.
    func cancel() async {
        await repository.cancel()

        updateFailure()
    }

    /// Returns a finished flow to its starting point so the user can try again.
    func startOver() {
        repository.reset()

        failure = nil
    }

    private func updateFailure() {
        guard let failure = repository.failure else {
            self.failure = nil

            return
        }

        self.failure = UserFacingFailure(
            title      : Self.title(for: failure),
            message    : failure.message,
            isRetryable: failure.isRetryable
        )
    }

    private static func title(for failure: EncryptionFailure) -> String {
        switch failure {
            case .noActiveClient               : "No account to verify"
            case .verificationUnavailable      : "Verification is unavailable"
            case .invalidRecoveryKey           : "That key did not work"
            case .recoveryFailed               : "Recovery failed"
            case .backupFailed                 : "Key backup failed"
            case .unsupportedVerificationMethod: "Swix cannot show this comparison"
            case .sdk                          : "Verification could not be completed"
        }
    }
}
