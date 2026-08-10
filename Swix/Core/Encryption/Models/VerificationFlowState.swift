//
//  VerificationFlowState.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// Every position the interactive SAS verification can be in, from both sides of the flow.
///
/// The order of the cases follows the happy path: a flow always moves forward through them, and can
/// leave for `cancelled` or `failed` at any point, which is what makes the screen a pure function
/// of this value.
enum VerificationFlowState: Equatable {

    /// Nothing is running. Terminal states are reset back to this before a new attempt.
    case idle

    /// This device asked another session to verify it and is waiting for an answer.
    case requested

    /// Another session asked to verify this one, Swix acknowledged it, and the user still has to
    /// accept or decline.
    case waitingForAcceptance

    /// Both sides agreed to verify; the short authentication string exchange is about to begin.
    case accepted

    /// The SAS exchange started and the emojis have not arrived yet.
    case sasStarted

    /// The emojis are on screen and the user has to say whether they match the other device.
    case showingEmojis([EmojiPair])

    /// The user confirmed the match and the confirmation is on its way to the homeserver.
    case approving

    /// Both sides confirmed: this device is now signed by the account identity.
    case verified

    /// Either side walked away, including the user declining a mismatch.
    case cancelled

    /// The flow ended in an error rather than a decision.
    case failed

    /// The emojis to compare, empty unless the flow is waiting on the user's answer.
    var emojis: [EmojiPair] {
        switch self {
            case .showingEmojis(let emojis): emojis
            default                        : []
        }
    }

    /// Whether the flow has reached an outcome and can only be restarted, not advanced.
    var isTerminal: Bool {
        switch self {
            case .verified, .cancelled, .failed: true
            default                            : false
        }
    }

    /// Whether the flow is waiting on the network rather than on the user.
    var isBusy: Bool {
        switch self {
            case .requested, .accepted,
                 .sasStarted, .approving: true
            default                     : false
        }
    }
}
