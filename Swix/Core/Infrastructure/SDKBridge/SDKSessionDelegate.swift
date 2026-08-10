//
//  SDKSessionDelegate.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import os


/// Gives the SDK synchronous access to the stored session so it can rotate tokens on its own.
///
/// Both methods are invoked from Rust threads in the middle of a request, so the whole keychain
/// round trip happens inline here rather than being handed to a task.
nonisolated final class SDKSessionDelegate: ClientSessionDelegate {

    private static let logger = Logger(subsystem: "hylo.Swix", category: "session")

    private static let nativeSlidingSyncName = "native"

    private static let noneSlidingSyncName = "none"

    private let keychain: SessionKeychain

    init(keychain: SessionKeychain) {
        self.keychain = keychain
    }

    /// Returns the session the SDK should use for a user, or throws when nothing is stored.
    ///
    /// Every failure is remapped to `ClientError` because that is the only error the generated
    /// callback vtable knows how to hand back to Rust.
    func retrieveSessionFromKeychain(userId: String) throws -> Session {
        do {
            guard let persisted = try keychain.session(account: userId) else {
                throw SessionKeychainError.decodingFailure(reason: "no session stored for this user")
            }

            return makeSession(from: persisted)
        } catch {
            Self.logger.error("Could not read the session from the keychain: \(String(describing: error))")

            throw ClientError.Generic(msg: "No usable session in the keychain", details: String(describing: error))
        }
    }

    /// Persists a session the SDK just rotated. Failures can only be logged, the SDK ignores them.
    func saveSessionInKeychain(session: Session) {
        do {
            try keychain.save(makePersistedSession(from: session))
        } catch {
            Self.logger.error("Could not persist the rotated session: \(String(describing: error))")
        }
    }

    private func makeSession(from persisted: PersistedSession) -> Session {
        Session(
            accessToken       : persisted.accessToken,
            refreshToken      : persisted.refreshToken,
            userId            : persisted.userID,
            deviceId          : persisted.deviceID,
            homeserverUrl     : persisted.homeserverURL,
            oauthData         : persisted.oauthData,
            slidingSyncVersion: makeSlidingSyncVersion(from: persisted.slidingSyncVersion)
        )
    }

    private func makePersistedSession(from session: Session) -> PersistedSession {
        PersistedSession(
            accessToken       : session.accessToken,
            refreshToken      : session.refreshToken,
            userID            : session.userId,
            deviceID          : session.deviceId,
            homeserverURL     : session.homeserverUrl,
            oauthData         : session.oauthData,
            slidingSyncVersion: makeName(of: session.slidingSyncVersion)
        )
    }

    private func makeSlidingSyncVersion(from name: String) -> SlidingSyncVersion {
        switch name {
            case Self.nativeSlidingSyncName: .native
            default: .none
        }
    }

    private func makeName(of version: SlidingSyncVersion) -> String {
        switch version {
            case .native: Self.nativeSlidingSyncName
            case .none: Self.noneSlidingSyncName
        }
    }
}
