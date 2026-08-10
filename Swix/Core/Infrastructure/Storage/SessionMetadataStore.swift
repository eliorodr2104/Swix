//
//  SessionMetadataStore.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Tracks which account is currently active across app relaunches.
///
/// Deliberately separate from the keychain: it holds no secret, only enough to know which
/// keychain item and which `SessionDirectories` to load back on next launch.
final class SessionMetadataStore {

    private static let activeUserIDKey = "hylo.Swix.activeUserID"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The Matrix user ID of the signed-in account, if any.
    var activeUserID: String? {
        get { defaults.string(forKey: Self.activeUserIDKey) }
        set { defaults.set(newValue, forKey: Self.activeUserIDKey) }
    }

    /// Forgets the active account, e.g. after logout.
    func clear() {
        defaults.removeObject(forKey: Self.activeUserIDKey)
    }
}
