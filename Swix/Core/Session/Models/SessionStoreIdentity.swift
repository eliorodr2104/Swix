//
//  SessionStoreIdentity.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Where one client keeps its encrypted state on disk, and the secret that unlocks it.
///
/// The folder is named after a random identifier rather than the Matrix user ID because it has to
/// exist before login, when the account the client will end up owning is still unknown.
struct SessionStoreIdentity: Codable, Equatable {

    /// Seed of the session directory names, stable for the whole life of the account.
    let directoryIdentifier: String

    /// Passphrase of the SQLite stores and of the local search index.
    let storePassphrase: String

    init(directoryIdentifier: String, storePassphrase: String) {
        self.directoryIdentifier = directoryIdentifier
        self.storePassphrase     = storePassphrase
    }

    /// Mints the identity of a session that does not exist yet, for a client about to log in.
    ///
    /// It only becomes the identity of an account once the login succeeds and it is persisted
    /// next to the session; until then the directories it names are throwaway.
    static func makeProvisional() -> SessionStoreIdentity {
        SessionStoreIdentity(
            directoryIdentifier: UUID().uuidString,
            storePassphrase    : makePassphrase()
        )
    }

    /// Draws a 32 byte secret from the system generator, which is the platform CSPRNG.
    private static func makePassphrase() -> String {
        var bytes = [UInt8]()
        bytes.reserveCapacity(32)

        for _ in 0..<32 {
            bytes.append(UInt8.random(in: .min ... .max))
        }

        return Data(bytes).base64EncodedString()
    }
}
