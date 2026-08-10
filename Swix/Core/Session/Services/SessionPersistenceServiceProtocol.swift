//
//  SessionPersistenceServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Owns everything that outlives a launch for a session: the credentials, the store identity, the
/// pointer to the active account and the directories on disk.
protocol SessionPersistenceServiceProtocol {

    /// The credentials of the account marked active, or nil when nobody is signed in.
    func loadActive() throws -> PersistedSession?

    /// Where the stores of an account live and how to unlock them.
    func storeIdentity(for userID: String) throws -> SessionStoreIdentity?

    /// Records a freshly authenticated account and marks it active.
    func persist(
        _ session    : PersistedSession,
        storeIdentity: SessionStoreIdentity
    ) throws

    /// Wipes the active account: credentials, store identity, session directories and metadata.
    func clearActive()

    /// Drops everything belonging to accounts that are not the active one.
    ///
    /// Reinstalling the app empties the containers but not the keychain, so without this a stale
    /// item would survive forever, pointing at directories that no longer exist.
    func purgeOrphans()
}
