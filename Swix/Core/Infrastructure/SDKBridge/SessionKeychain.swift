//
//  SessionKeychain.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Security


/// The credentials Swix persists between launches, modelled as our own DTO so that no SDK type is
/// ever written to disk and the on disk format stays stable across SDK upgrades.
nonisolated struct PersistedSession: Codable, Equatable, Sendable {

    /// The token every authenticated request is signed with.
    let accessToken: String

    /// The refresh token, present only when the homeserver rotates tokens.
    let refreshToken: String?

    /// The Matrix user this session belongs to, and the keychain account it is filed under.
    let userID: String

    /// The device the session logged in as.
    let deviceID: String

    /// The homeserver this session talks to.
    let homeserverURL: String

    /// Opaque OAuth material the SDK needs to refresh tokens, when OAuth was used to log in.
    let oauthData: String?

    /// The sliding sync flavour negotiated at login, kept as a plain string to stay SDK free.
    let slidingSyncVersion: String

    init(
        accessToken       : String,
        refreshToken      : String?,
        userID            : String,
        deviceID          : String,
        homeserverURL     : String,
        oauthData         : String?,
        slidingSyncVersion: String
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userID = userID
        self.deviceID = deviceID
        self.homeserverURL = homeserverURL
        self.oauthData = oauthData
        self.slidingSyncVersion = slidingSyncVersion
    }
}

/// Everything that can go wrong while talking to the keychain.
nonisolated enum SessionKeychainError: Error, Sendable {

    /// The session could not be turned into JSON.
    case encodingFailure(reason: String)

    /// The stored payload was missing or could not be read back as a session.
    case decodingFailure(reason: String)

    /// The Security framework returned a status we do not treat as success.
    case unexpectedStatus(OSStatus)
}

/// Stores one `PersistedSession` per Matrix user in the keychain.
///
/// The SDK reads and writes sessions synchronously from its own threads, so this type is
/// nonisolated and stateless: the SecItem APIs are already thread safe, no lock is needed.
nonisolated final class SessionKeychain: Sendable {

    private let service: String

    /// `service` defaults to the app's own keychain service; tests pass a unique one so their
    /// items never collide with each other or with whatever a real session left behind.
    init(service: String = "hylo.Swix.session") {
        self.service = service
    }

    /// Writes the session, updating the existing item when there is one.
    ///
    /// The update or add order matters: deleting first would leave the user logged out for good if
    /// the process died between the two calls, since a refresh token cannot be recovered.
    func save(_ session: PersistedSession) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: try encode(session),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let query = itemQuery(account: session.userID)
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw SessionKeychainError.unexpectedStatus(updateStatus)
        }

        let addStatus = SecItemAdd(query.merging(attributes) { current, _ in current } as CFDictionary, nil)

        guard addStatus == errSecSuccess else {
            throw SessionKeychainError.unexpectedStatus(addStatus)
        }
    }

    /// Reads the session stored for a Matrix user, or nil when that user never logged in here.
    func session(account: String) throws -> PersistedSession? {
        var query = itemQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw SessionKeychainError.unexpectedStatus(status)
        }

        guard let data = item as? Data else {
            throw SessionKeychainError.decodingFailure(reason: "the keychain item carried no data")
        }

        return try decode(data)
    }

    /// Lists the Matrix user identifiers that currently have a stored session.
    func listAccounts() throws -> [String] {
        var query = serviceQuery
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll

        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)

        if status == errSecItemNotFound {
            return []
        }

        guard status == errSecSuccess else {
            throw SessionKeychainError.unexpectedStatus(status)
        }

        guard let attributes = items as? [[String: Any]] else {
            throw SessionKeychainError.decodingFailure(reason: "the keychain returned unexpected attributes")
        }

        return attributes.compactMap { $0[kSecAttrAccount as String] as? String }
    }

    /// Removes the session stored for a Matrix user. Deleting a missing item is not an error.
    func delete(account: String) throws {
        let status = SecItemDelete(itemQuery(account: account) as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SessionKeychainError.unexpectedStatus(status)
        }
    }

    /// The query matching every session item written by this app.
    private var serviceQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
    }

    /// The query matching the single item of one Matrix user.
    private func itemQuery(account: String) -> [String: Any] {
        var query = serviceQuery
        query[kSecAttrAccount as String] = account

        return query
    }

    private func encode(_ session: PersistedSession) throws -> Data {
        do {
            return try JSONEncoder().encode(session)
        } catch {
            throw SessionKeychainError.encodingFailure(reason: String(describing: error))
        }
    }

    private func decode(_ data: Data) throws -> PersistedSession {
        do {
            return try JSONDecoder().decode(PersistedSession.self, from: data)
        } catch {
            throw SessionKeychainError.decodingFailure(reason: String(describing: error))
        }
    }
}
