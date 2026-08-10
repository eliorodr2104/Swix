//
//  VerificationEvent.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// What the verification controller reported, already stripped of every SDK type.
///
/// The bridge flattens the SDK delegate into `SDKVerificationEvent`, whose payloads are still SDK
/// structs; this is the shape the repository is allowed to see, so the state machine can be written
/// without importing the SDK.
enum VerificationEvent: Equatable {

    /// Another session asked to verify this one. The two identifiers are what the flow has to be
    /// acknowledged with before any further event arrives for it.
    case requestReceived(
        senderID         : String,
        flowID           : String,
        deviceID         : String,
        deviceDisplayName: String?
    )

    /// The request reached the accepted state on both sides.
    case requestAccepted

    /// The short authentication string exchange began.
    case sasStarted

    /// The emojis to compare are ready.
    case emojisReceived([EmojiPair])

    /// The other side negotiated decimal SAS, which Swix has no screen for.
    case unsupportedDataReceived

    /// The flow ended in an error.
    case failed

    /// Either side cancelled the flow.
    case cancelled

    /// The flow completed and this device is now verified.
    case finished
}
