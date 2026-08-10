//
//  PersistedSessionMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Translates between the SDK's `Session`, the DTO we persist and the model the app shows.
///
/// The sliding sync flavour is encoded exactly as `SDKSessionDelegate` encodes it: the two sides
/// write the same keychain item, so a mismatch would silently downgrade a restored session.
enum PersistedSessionMapper {

    private static let nativeSlidingSyncName = "native"

    private static let noneSlidingSyncName = "none"

    /// Turns the session the SDK just issued into the DTO we can store.
    static func makePersistedSession(
        from session: Session
    ) -> PersistedSession {
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

    /// Turns a stored DTO back into the session the SDK expects for `restoreSession`.
    static func makeSession(from persisted: PersistedSession) -> Session {
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

    /// Projects a stored DTO onto the model the rest of the app consumes, secrets stripped.
    static func makeUserSession(
        from persisted: PersistedSession
    ) -> UserSession {
        UserSession(
            userID       : persisted.userID,
            deviceID     : persisted.deviceID,
            homeserverURL: persisted.homeserverURL,
            usedOAuth    : persisted.oauthData != nil
        )
    }

    private static func makeSlidingSyncVersion(
        from name: String
    ) -> SlidingSyncVersion {
        switch name {
            case nativeSlidingSyncName: .native
            default: .none
        }
    }

    private static func makeName(of version: SlidingSyncVersion) -> String {
        switch version {
            case .native: nativeSlidingSyncName
            case .none: noneSlidingSyncName
        }
    }
}
