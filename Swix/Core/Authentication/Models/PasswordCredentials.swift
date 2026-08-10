//
//  PasswordCredentials.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation

/// What the user typed in the password form, trimmed and checked just enough to avoid a pointless
/// round trip to the homeserver.
struct PasswordCredentials: Equatable {

    /// A localpart (`alice`) or a full Matrix identifier (`@alice:matrix.org`); the SDK accepts both.
    let username: String

    /// The password exactly as typed, never trimmed: leading and trailing spaces are legal in one.
    let password: String

    init(
        username: String,
        password: String
    ) {
        self.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        self.password = password
    }

    /// Whether both fields carry something worth sending.
    var isValid: Bool { !username.isEmpty && !password.isEmpty }
}
