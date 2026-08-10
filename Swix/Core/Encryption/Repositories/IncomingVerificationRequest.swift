//
//  IncomingVerificationRequest.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// The identity of the session that asked to verify this one.
struct IncomingVerificationRequest: Equatable {

    /// The Matrix user the request came from, which for self verification is the account itself.
    let senderID: String

    /// Identifier of the verification flow, needed to acknowledge it.
    let flowID: String

    /// The device asking for the verification.
    let deviceID: String

    /// Human readable name of that device, when it published one.
    let deviceDisplayName: String?
}
