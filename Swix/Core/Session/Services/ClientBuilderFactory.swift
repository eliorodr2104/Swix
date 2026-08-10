//
//  ClientBuilderFactory.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import MatrixRustSDK


/// The single place where a `ClientBuilder` is configured, so that a client built to log in and a
/// client built to restore a session differ only by the homeserver they are pointed at.
struct ClientBuilderFactory: ClientBuilderFactoryProtocol {

    private let sessionKeychain: SessionKeychain

    init(sessionKeychain: SessionKeychain) {
        self.sessionKeychain = sessionKeychain
    }

    func makeBuilder(
        serverNameOrHomeserverURL: String,
        storeIdentity            : SessionStoreIdentity
    ) throws -> ClientBuilder {
        try makeConfiguredBuilder(storeIdentity: storeIdentity)
            .serverNameOrHomeserverUrl(serverNameOrUrl: serverNameOrHomeserverURL)
    }

    func makeBuilder(
        homeserverURL: String,
        storeIdentity: SessionStoreIdentity
    ) throws -> ClientBuilder {
        try makeConfiguredBuilder(storeIdentity: storeIdentity)
            .homeserverUrl(url: homeserverURL)
    }

    private func makeConfiguredBuilder(
        storeIdentity: SessionStoreIdentity
    ) throws -> ClientBuilder {
        TracingSetup.ensureInitialized()

        // The directories are named after the store identity rather than the Matrix user ID: a
        // client being built to log in does not know yet which account it will end up owning.
        let directories = try SessionDirectories(userID: storeIdentity.directoryIdentifier)

        let dataPath = directories.dataPath.path(percentEncoded: false)
        let cachePath = directories.cachePath.path(percentEncoded: false)

        let store = SqliteStoreBuilder(
            dataPath : dataPath,
            cachePath: cachePath
        )
            .passphrase(passphrase: storeIdentity.storePassphrase)

        return ClientBuilder()
            .sessionPaths(
                dataPath : dataPath,
                cachePath: cachePath
            )
            .sqliteStore(config: store)
            .withSearchIndexStore(
                path    : try makeSearchIndexPath(in: directories.dataPath),
                password: storeIdentity.storePassphrase
            )
            .slidingSyncVersionBuilder(versionBuilder: .discoverNative)
            .setSessionDelegate(sessionDelegate: SDKSessionDelegate(keychain: sessionKeychain))
            .userAgent(userAgent: MatrixConfiguration.userAgent)
            .autoEnableCrossSigning(autoEnableCrossSigning: true)
            .autoEnableBackups(autoEnableBackups: true)
            .backupDownloadStrategy(backupDownloadStrategy: .afterDecryptionFailure)
            .threadsEnabled(
                enabled            : true,
                threadSubscriptions: true
            )
    }

    /// Creates the Tantivy index directory up front so it inherits the same file protection as
    /// the rest of the session data instead of whatever the SDK would create it with.
    private func makeSearchIndexPath(in dataPath: URL) throws -> String {
        let url = dataPath.appendingPathComponent(
            MatrixConfiguration.searchIndexSubpath,
            isDirectory: true
        )

        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )

        return url.path(percentEncoded: false)
    }
}
