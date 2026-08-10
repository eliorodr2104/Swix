//
//  SessionPersistenceService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import os


/// Combines the two keychain stores, the metadata store and the session directories into the one
/// place that knows what "being signed in" means on disk.
final class SessionPersistenceService: SessionPersistenceServiceProtocol {

    private let sessionKeychain: SessionKeychain

    private let storeIdentityKeychain: SessionStoreIdentityKeychain

    private let metadataStore: SessionMetadataStore

    init(
        sessionKeychain      : SessionKeychain,
        storeIdentityKeychain: SessionStoreIdentityKeychain = SessionStoreIdentityKeychain(),
        metadataStore        : SessionMetadataStore = SessionMetadataStore()
    ) {
        self.sessionKeychain       = sessionKeychain
        self.storeIdentityKeychain = storeIdentityKeychain
        self.metadataStore         = metadataStore
    }

    var hasStoredAccount: Bool {
        metadataStore.activeUserID != nil
    }

    func loadActive() throws -> PersistedSession? {
        guard let userID = metadataStore.activeUserID else {
            return nil
        }

        do {
            return try sessionKeychain.session(account: userID)
        } catch {
            throw SessionFailure.keychainUnavailable(reason: String(describing: error))
        }
    }

    func storeIdentity(for userID: String) throws -> SessionStoreIdentity? {
        do {
            return try storeIdentityKeychain.identity(account: userID)
        } catch {
            throw SessionFailure.keychainUnavailable(reason: String(describing: error))
        }
    }

    /// The write order matters: an interruption may leave an identity nobody references, which is
    /// harmless, whereas a session whose stores cannot be unlocked would be unusable forever.
    func persist(
        _ session    : PersistedSession,
        storeIdentity: SessionStoreIdentity
    ) throws {
        do {
            try storeIdentityKeychain.save(
                storeIdentity,
                account: session.userID
            )

            try sessionKeychain.save(session)
        } catch {
            throw SessionFailure.keychainUnavailable(reason: String(describing: error))
        }

        metadataStore.activeUserID = session.userID
    }

    func clearActive() {
        if let userID = metadataStore.activeUserID {
            forget(account: userID)
        }

        metadataStore.clear()
    }

    func purgeOrphans() {
        let activeUserID = metadataStore.activeUserID

        let sessionAccounts = (try? sessionKeychain.listAccounts()) ?? []
        let identityAccounts = (try? storeIdentityKeychain.listAccounts()) ?? []

        for account in Set(sessionAccounts + identityAccounts) where account != activeUserID {
            Log.session.notice("Purging the leftover session of an account that is not signed in")

            forget(account: account)
        }
    }

    /// Removes every trace of an account. Teardown must never get stuck, so failures are logged.
    private func forget(account userID: String) {
        if let identity = try? storeIdentityKeychain.identity(account: userID) {
            SessionDirectories.deleteAll(for: identity.directoryIdentifier)
        }

        do {
            try storeIdentityKeychain.delete(account: userID)
        } catch {
            Log.session.error("Could not delete the store identity: \(String(reflecting: error), privacy: .public)")
        }

        do {
            try sessionKeychain.delete(account: userID)
        } catch {
            Log.session.error("Could not delete the stored session: \(String(reflecting: error), privacy: .public)")
        }
    }
}
