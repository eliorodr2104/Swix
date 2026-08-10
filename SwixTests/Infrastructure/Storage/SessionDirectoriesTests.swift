//
//  SessionDirectoriesTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing
@testable import Swix


/// Covers directory creation, stable hashing per user ID and teardown, against the real
/// filesystem, cleaning up after itself with `deleteAll` on every test.
@Suite("SessionDirectories")
struct SessionDirectoriesTests {

    @Test("init creates both the data and the cache directory on disk")
    func initCreatesBothDirectories() throws {
        let userID = "@\(UUID().uuidString):example.org"
        let directories = try SessionDirectories(userID: userID)

        defer { SessionDirectories.deleteAll(for: userID) }

        var isDataDirectory: ObjCBool = false
        var isCacheDirectory: ObjCBool = false

        let dataExists = FileManager.default.fileExists(
            atPath     : directories.dataPath.path,
            isDirectory: &isDataDirectory
        )

        let cacheExists = FileManager.default.fileExists(
            atPath     : directories.cachePath.path,
            isDirectory: &isCacheDirectory
        )

        #expect(dataExists && isDataDirectory.boolValue)
        #expect(cacheExists && isCacheDirectory.boolValue)
    }

    @Test("the same user ID always resolves to the same directories")
    func sameUserIDResolvesToTheSamePaths() throws {
        let userID = "@\(UUID().uuidString):example.org"

        let first = try SessionDirectories(userID: userID)
        defer { SessionDirectories.deleteAll(for: userID) }

        let second = try SessionDirectories(userID: userID)

        #expect(first.dataPath == second.dataPath)
        #expect(first.cachePath == second.cachePath)
    }

    @Test("different user IDs resolve to different directories")
    func differentUserIDsResolveToDifferentPaths() throws {
        let firstUserID = "@\(UUID().uuidString):example.org"
        let secondUserID = "@\(UUID().uuidString):example.org"

        let first = try SessionDirectories(userID: firstUserID)
        defer { SessionDirectories.deleteAll(for: firstUserID) }

        let second = try SessionDirectories(userID: secondUserID)
        defer { SessionDirectories.deleteAll(for: secondUserID) }

        #expect(first.dataPath != second.dataPath)
        #expect(first.cachePath != second.cachePath)
    }

    @Test("no Matrix ID appears anywhere in the resolved paths")
    func pathsDoNotLeakTheUserID() throws {
        let userID = "@alice:example.org"
        let directories = try SessionDirectories(userID: userID)

        defer { SessionDirectories.deleteAll(for: userID) }

        #expect(!directories.dataPath.path.contains("alice"))
        #expect(!directories.cachePath.path.contains("alice"))
    }

    @Test("deleteAll removes both directories, leaving nothing behind")
    func deleteAllRemovesBothDirectories() throws {
        let userID = "@\(UUID().uuidString):example.org"
        let directories = try SessionDirectories(userID: userID)

        SessionDirectories.deleteAll(for: userID)

        #expect(!FileManager.default.fileExists(atPath: directories.dataPath.path))
        #expect(!FileManager.default.fileExists(atPath: directories.cachePath.path))
    }

    @Test("deleteAll for a user that never had directories does not throw or crash")
    func deleteAllForUnknownUserIsHarmless() {
        SessionDirectories.deleteAll(for: "@\(UUID().uuidString):example.org")
    }
}
