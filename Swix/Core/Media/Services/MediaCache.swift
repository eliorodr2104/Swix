//
//  MediaCache.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import CryptoKit
import Foundation
import os


/// The default `MediaCacheProtocol`: least recently used eviction over a directory in Caches.
///
/// It is a plain main actor type rather than an actor because every caller is already on the main
/// actor and the payloads are thumbnails, small enough that the writes never justify hopping off it.
final class MediaCache: MediaCacheProtocol {

    private struct Entry {

        let url: URL

        let byteCount: Int

        var lastAccess: Date
    }

    private let directory: URL?

    private let maximumByteCount: Int

    private var entries: [String: Entry] = [:]

    private(set) var currentByteCount = 0

    /// Creates the cache directory and adopts whatever survived the last run.
    init(
        directoryName   : String = "MediaThumbnails",
        maximumByteCount: Int    = 256 * 1024 * 1024
    ) {
        self.maximumByteCount = maximumByteCount

        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            Log.media.error("MediaCache: caches directory unavailable, caching disabled")
            directory = nil
            return
        }

        let root = caches.appendingPathComponent(directoryName, isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: root,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )

            directory = root
        } catch {
            Log.media.error("MediaCache: failed creating \(directoryName, privacy: .public): \(String(reflecting: error), privacy: .public)")
            directory = nil
            return
        }

        loadExistingEntries(in: root)
    }

    func data(forKey key: String) -> Data? {
        let name = fileName(for: key)

        guard var entry = entries[name] else {
            return nil
        }

        guard let data = try? Data(contentsOf: entry.url) else {
            forget(name: name)
            return nil
        }

        entry.lastAccess = Date()
        entries[name] = entry
        touch(entry.url, at: entry.lastAccess)

        return data
    }

    func store(_ data: Data, forKey key: String) {
        guard let directory else {
            return
        }

        let name = fileName(for: key)
        let url = directory.appendingPathComponent(name, isDirectory: false)

        do {
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            Log.media.error("MediaCache: failed writing entry: \(String(reflecting: error), privacy: .public)")
            return
        }

        if let previous = entries[name] {
            currentByteCount -= previous.byteCount
        }

        entries[name] = Entry(url: url, byteCount: data.count, lastAccess: Date())
        currentByteCount += data.count

        evictIfNeeded()
    }

    func removeAll() {
        for name in Array(entries.keys) {
            forget(name: name)
        }
    }

    /// Rebuilds the index from disk so a cache survives relaunches instead of growing forever
    /// behind an empty in memory view of itself.
    private func loadExistingEntries(in directory: URL) {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for url in contents {
            let values = try? url.resourceValues(forKeys: keys)
            let byteCount = values?.fileSize ?? 0
            let lastAccess = values?.contentModificationDate ?? .distantPast

            entries[url.lastPathComponent] = Entry(url: url, byteCount: byteCount, lastAccess: lastAccess)
            currentByteCount += byteCount
        }

        evictIfNeeded()
    }

    /// Drops the least recently used entry, one at a time, until the cache fits its budget again.
    private func evictIfNeeded() {
        while currentByteCount > maximumByteCount {
            guard let oldest = entries.min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key else {
                return
            }

            forget(name: oldest)
        }
    }

    private func forget(name: String) {
        guard let entry = entries.removeValue(forKey: name) else {
            return
        }

        currentByteCount -= entry.byteCount

        try? FileManager.default.removeItem(at: entry.url)
    }

    /// The modification date doubles as the access date, since it is the only timestamp that both
    /// survives a relaunch and can be rewritten without reading the file back.
    private func touch(_ url: URL, at date: Date) {
        try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path(percentEncoded: false))
    }

    /// Hashes the caller's key so any string, including one carrying a URI, is a legal file name.
    private func fileName(for key: String) -> String {
        let digest = SHA256.hash(data: Data(key.utf8))

        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
