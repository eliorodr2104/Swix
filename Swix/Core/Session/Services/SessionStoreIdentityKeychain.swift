//
//  SessionStoreIdentityKeychain.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Security


/// Stores one `SessionStoreIdentity` per Matrix user, next to but separate from the session item.
///
/// It lives in its own keychain service because `SessionKeychain` is written from Rust threads by
/// the SDK's session delegate, while this one is only ever touched by our own session flow.
final class SessionStoreIdentityKeychain {

    private let service = "hylo.Swix.storeIdentity"

    init() {}

    /// Writes the identity of an account, updating the existing item when there is one.
    func save(_ identity: SessionStoreIdentity, account: String) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: try encode(identity),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let query = itemQuery(account: account)
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

    /// Reads the identity of an account, or nil when that account never stored one.
    func identity(account: String) throws -> SessionStoreIdentity? {
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

    /// Lists the accounts that currently have a stored identity.
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

    /// Removes the identity of an account. Deleting a missing item is not an error.
    func delete(account: String) throws {
        let status = SecItemDelete(itemQuery(account: account) as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SessionKeychainError.unexpectedStatus(status)
        }
    }

    private var serviceQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
    }

    private func itemQuery(account: String) -> [String: Any] {
        var query = serviceQuery
        query[kSecAttrAccount as String] = account

        return query
    }

    private func encode(_ identity: SessionStoreIdentity) throws -> Data {
        do {
            return try JSONEncoder().encode(identity)
        } catch {
            throw SessionKeychainError.encodingFailure(reason: String(describing: error))
        }
    }

    private func decode(_ data: Data) throws -> SessionStoreIdentity {
        do {
            return try JSONDecoder().decode(SessionStoreIdentity.self, from: data)
        } catch {
            throw SessionKeychainError.decodingFailure(reason: String(describing: error))
        }
    }
}
