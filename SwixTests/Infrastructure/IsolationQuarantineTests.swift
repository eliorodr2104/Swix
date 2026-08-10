//
//  IsolationQuarantineTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing


/// Guards the one architectural rule that a compiler cannot check: `nonisolated` and
/// `@unchecked Sendable` are only ever supposed to appear under `Infrastructure/SDKBridge`, the
/// single place UniFFI's synchronous, thread-hopping callbacks are allowed to touch Swift
/// concurrency directly.
///
/// This scans the actual source tree rather than asserting anything about specific files, so it
/// keeps catching a violation even after every file it does not yet know about.
@Suite("Isolation quarantine")
struct IsolationQuarantineTests {

    private static let allowedPrefix = "Infrastructure/SDKBridge/"

    @Test("nonisolated and @unchecked Sendable appear only under Infrastructure/SDKBridge")
    func quarantineIsRespected() throws {
        let coreRoot = try Self.locateCoreRoot()
        let violations = try Self.findViolations(under: coreRoot)

        #expect(
            violations.isEmpty,
            "Found nonisolated or @unchecked Sendable outside Infrastructure/SDKBridge: \(violations.joined(separator: ", "))"
        )
    }

    /// Finds `Swix/Core` relative to this very file, so the test keeps working no matter where
    /// the repository is checked out.
    private static func locateCoreRoot() throws -> URL {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // SwixTests/Infrastructure
            .deletingLastPathComponent() // SwixTests
            .deletingLastPathComponent() // the checkout itself

        let coreRoot = repoRoot.appendingPathComponent("Swix/Core", isDirectory: true)

        guard FileManager.default.fileExists(atPath: coreRoot.path) else {
            struct CoreRootNotFound: Error {}
            throw CoreRootNotFound()
        }

        return coreRoot
    }

    /// Every `.swift` file under `coreRoot` whose text mentions the guarded tokens outside the
    /// one folder allowed to use them, reported as `relative/path.swift: token`.
    private static func findViolations(under coreRoot: URL) throws -> [String] {
        guard let enumerator = FileManager.default.enumerator(
            at                        : coreRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options                   : [.skipsHiddenFiles]
        ) else {
            struct CannotEnumerateCore: Error {}
            throw CannotEnumerateCore()
        }

        var violations: [String] = []

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let relativePath = String(fileURL.path.dropFirst(coreRoot.path.count + 1))

            guard !relativePath.hasPrefix(allowedPrefix) else {
                continue
            }

            let contents = try String(contentsOf: fileURL, encoding: .utf8)

            if contents.contains("nonisolated") {
                violations.append("\(relativePath): nonisolated")
            }

            if contents.contains("@unchecked Sendable") {
                violations.append("\(relativePath): @unchecked Sendable")
            }
        }

        return violations
    }
}
