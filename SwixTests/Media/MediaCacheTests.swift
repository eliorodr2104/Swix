//
//  MediaCacheTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing
@testable import Swix


@Suite("MediaCache")
struct MediaCacheTests {

    @Test("a stored value can be read back under the same key")
    func storeAndReadBack() {
        let cache = Self.makeCache()
        defer { cache.removeAll() }

        cache.store(Data([0x1, 0x2, 0x3]), forKey: "one")

        #expect(cache.data(forKey: "one") == Data([0x1, 0x2, 0x3]))
        #expect(cache.currentByteCount == 3)
    }

    @Test("an unknown key reads back nil")
    func unknownKeyReadsNil() {
        let cache = Self.makeCache()
        defer { cache.removeAll() }

        #expect(cache.data(forKey: "missing") == nil)
    }

    @Test("storing over the budget evicts the least recently used entry first")
    func exceedingBudgetEvictsLeastRecentlyUsed() {
        // Each entry is 4 bytes; a budget of 10 fits two but not three.
        let cache = Self.makeCache(maximumByteCount: 10)
        defer { cache.removeAll() }

        cache.store(Data(repeating: 0xA, count: 4), forKey: "first")
        cache.store(Data(repeating: 0xB, count: 4), forKey: "second")
        cache.store(Data(repeating: 0xC, count: 4), forKey: "third")

        #expect(cache.data(forKey: "first") == nil)
        #expect(cache.data(forKey: "second") != nil)
        #expect(cache.data(forKey: "third") != nil)
        #expect(cache.currentByteCount <= 10)
    }

    @Test("reading an entry marks it most recently used, so a newer write evicts someone else instead")
    func readingEntryProtectsItFromEviction() {
        let cache = Self.makeCache(maximumByteCount: 10)
        defer { cache.removeAll() }

        cache.store(Data(repeating: 0xA, count: 4), forKey: "first")
        cache.store(Data(repeating: 0xB, count: 4), forKey: "second")

        // Touch "first" so it becomes the most recently used of the two.
        _ = cache.data(forKey: "first")

        cache.store(Data(repeating: 0xC, count: 4), forKey: "third")

        #expect(cache.data(forKey: "first") != nil)
        #expect(cache.data(forKey: "second") == nil)
        #expect(cache.data(forKey: "third") != nil)
    }

    @Test("overwriting a key replaces its byte count rather than adding to it")
    func overwritingKeyReplacesByteCount() {
        let cache = Self.makeCache()
        defer { cache.removeAll() }

        cache.store(Data(repeating: 0xA, count: 4), forKey: "one")
        cache.store(Data(repeating: 0xB, count: 6), forKey: "one")

        #expect(cache.currentByteCount == 6)
        #expect(cache.data(forKey: "one") == Data(repeating: 0xB, count: 6))
    }

    @Test("removeAll drops every entry and resets the byte count")
    func removeAllClearsEverything() {
        let cache = Self.makeCache()

        cache.store(Data([0x1]), forKey: "one")
        cache.store(Data([0x2]), forKey: "two")

        cache.removeAll()

        #expect(cache.currentByteCount == 0)
        #expect(cache.data(forKey: "one") == nil)
        #expect(cache.data(forKey: "two") == nil)
    }

    @Test("a cache reopened on the same directory adopts what survived the last run")
    func reopenedCacheAdoptsExistingEntries() {
        let directoryName = "SwixTests-MediaCache-\(UUID().uuidString)"

        let firstRun = MediaCache(directoryName: directoryName, maximumByteCount: 1024)

        firstRun.store(Data([0x1, 0x2]), forKey: "persisted")

        let secondRun = MediaCache(directoryName: directoryName, maximumByteCount: 1024)

        defer { secondRun.removeAll() }

        #expect(secondRun.data(forKey: "persisted") == Data([0x1, 0x2]))
        #expect(secondRun.currentByteCount == 2)
    }

    /// A uniquely named directory under the real Caches folder, torn down by each test's own
    /// `removeAll()`, which is the closest thing to an isolated temp directory `MediaCache`'s
    /// initializer allows: it always roots itself under `.cachesDirectory`.
    private static func makeCache(maximumByteCount: Int = 256 * 1024 * 1024) -> MediaCache {
        MediaCache(
            directoryName   : "SwixTests-MediaCache-\(UUID().uuidString)",
            maximumByteCount: maximumByteCount
        )
    }
}
