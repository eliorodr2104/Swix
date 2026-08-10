//
//  SessionDirectories.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import CryptoKit
import Foundation
import os


/// Filesystem locations for one Matrix account's SDK-managed state (SQLite store, search index).
///
/// Directories are named after a hash of the user ID rather than the ID itself, so nothing that
/// looks like a Matrix ID sits in a path an admin tool or a backup browser might casually show.
struct SessionDirectories {

    /// Passed straight to `ClientBuilder.sessionPaths(dataPath:cachePath:)`.
    let dataPath: URL

    /// Passed straight to `ClientBuilder.sessionPaths(dataPath:cachePath:)`.
    let cachePath: URL

    /// The one way resolving these paths can fail: the OS declined to hand back a system directory.
    private enum DirectoryError: Error {
        case systemDirectoryUnavailable
    }

    /// Resolves and creates both directories for `userID`, protected until first unlock.
    init(userID: String) throws {
        let identifier = Self.identifier(for: userID)

        guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw DirectoryError.systemDirectoryUnavailable
        }

        dataPath = applicationSupport
            .appendingPathComponent("Sessions", isDirectory: true)
            .appendingPathComponent(identifier, isDirectory: true)
            .appendingPathComponent("data", isDirectory: true)

        cachePath = caches
            .appendingPathComponent("Sessions", isDirectory: true)
            .appendingPathComponent(identifier, isDirectory: true)
            .appendingPathComponent("cache", isDirectory: true)

        try Self.createProtectedDirectory(at: dataPath)
        try Self.createProtectedDirectory(at: cachePath)
    }

    /// Permanently removes every file stored for `userID`, on both data and cache roots.
    /// Called on logout; failures are logged rather than thrown since teardown must not get stuck.
    static func deleteAll(for userID: String) {
        let identifier = identifier(for: userID)

        guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            Log.infrastructure.error("SessionDirectories.deleteAll: system directories unavailable")
            return
        }

        let dataRoot = applicationSupport.appendingPathComponent("Sessions", isDirectory: true).appendingPathComponent(identifier, isDirectory: true)
        let cacheRoot = caches.appendingPathComponent("Sessions", isDirectory: true).appendingPathComponent(identifier, isDirectory: true)

        do {
            try FileManager.default.removeItem(at: dataRoot)
        } catch {
            Log.infrastructure.error("SessionDirectories.deleteAll: failed removing data root: \(String(reflecting: error), privacy: .public)")
        }

        do {
            try FileManager.default.removeItem(at: cacheRoot)
        } catch {
            Log.infrastructure.error("SessionDirectories.deleteAll: failed removing cache root: \(String(reflecting: error), privacy: .public)")
        }
    }

    /// Creates `url` if it does not exist yet, protected so the contents stay encrypted until the
    /// device has been unlocked once after boot.
    private static func createProtectedDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(
            at                         : url,
            withIntermediateDirectories: true,
            attributes                 : [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
    }

    /// Turns a Matrix user ID into the short hash used as its directory name on disk.
    private static func identifier(for userID: String) -> String {
        let digest = SHA256.hash(data: Data(userID.utf8))
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(16))
    }
}
