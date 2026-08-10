//
//  MediaService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import MatrixRustSDK
import os


/// The default `MediaServiceProtocol`, built on the SDK client's media endpoints.
final class MediaService: MediaServiceProtocol {

    private let clientService: any ClientServiceProtocol

    private let cache: any MediaCacheProtocol

    /// SDK file handles delete their file on deinit, so any handle whose file we handed out must be
    /// kept alive here until the caller says it is done with it.
    private var retainedFileHandles: [URL: MediaFileHandle] = [:]

    /// The homeserver's upload limit never changes within a session, so it is worth one round trip.
    private var cachedMaximumUploadSize: Int?

    init(
        clientService: any ClientServiceProtocol,
        cache        : any MediaCacheProtocol = MediaCache()
    ) {

        self.clientService = clientService
        self.cache = cache
    }

    func upload(request: MediaUploadRequest) -> AsyncThrowingStream<MediaUploadEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                await self?.performUpload(request, continuation: continuation)
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func content(for item: MediaItem) async throws -> Data {
        let client = try activeClient()
        let source = try MediaSourceMapper.makeMediaSource(from: item)

        do {
            return try await client.getMediaContent(mediaSource: source)
        } catch {
            Log.media.error("Media content download failed: \(String(reflecting: error), privacy: .public)")

            throw MediaFailure.downloadFailed(SDKErrorInfo(error))
        }
    }

    func thumbnail(for item: MediaItem, width: Int, height: Int) async throws -> Data {
        let key = Self.thumbnailKey(for: item, width: width, height: height)

        if let cached = cache.data(forKey: key) {
            return cached
        }

        let client = try activeClient()
        let source = try MediaSourceMapper.makeMediaSource(from: item)

        do {
            let data = try await client.getMediaThumbnail(
                mediaSource: source,
                width      : UInt64(max(width, 1)),
                height     : UInt64(max(height, 1))
            )

            cache.store(data, forKey: key)

            return data
        } catch {
            Log.media.error("Media thumbnail download failed: \(String(reflecting: error), privacy: .public)")

            throw MediaFailure.downloadFailed(SDKErrorInfo(error))
        }
    }

    /// Downloads `item` and returns a URL the caller owns for as long as it wants.
    ///
    /// The SDK's handle erases its file the instant it deinits, so the file is first moved out of
    /// the SDK's ownership into our own directory; when the move is refused the handle is retained
    /// instead and `releaseFile(at:)` becomes the only thing keeping the file alive.
    func file(for item: MediaItem, filename: String?) async throws -> URL {
        let client = try activeClient()
        let source = try MediaSourceMapper.makeMediaSource(from: item)
        let resolvedName = filename ?? item.filename ?? item.cacheKey
        let handle: MediaFileHandle

        do {
            handle = try await client.getMediaFile(
                mediaSource: source,
                filename   : resolvedName,
                mimeType   : item.mimeType ?? "application/octet-stream",
                useCache   : true,
                tempDir    : nil
            )
        } catch {
            Log.media.error("Media file download failed: \(String(reflecting: error), privacy: .public)")

            throw MediaFailure.downloadFailed(SDKErrorInfo(error))
        }

        if let destination = try? Self.makeDestination(name: resolvedName, key: item.cacheKey),
           (try? handle.persist(path: destination.path(percentEncoded: false))) == true {
            return destination
        }

        do {
            let url = URL(fileURLWithPath: try handle.path())

            retainedFileHandles[url] = handle

            return url
        } catch {
            throw MediaFailure.fileUnavailable(reason: SDKErrorInfo(error).message)
        }
    }

    func maxUploadSize() async throws -> Int {
        try await maximumUploadSize(client: try activeClient())
    }

    func releaseFile(at url: URL) {
        retainedFileHandles[url] = nil
    }

    func shutdown() {
        retainedFileHandles.removeAll()
    }

    private func performUpload(
        _ request   : MediaUploadRequest,
        continuation: AsyncThrowingStream<MediaUploadEvent, any Error>.Continuation
    ) async {

        guard let client = clientService.sdkClient else {
            continuation.finish(throwing: MediaFailure.noActiveClient)
            return
        }

        // A limit lookup that fails must not block the upload: the homeserver will reject an
        // oversized file anyway, and refusing to even try would be worse than a wasted attempt.
        if let maximum = try? await maximumUploadSize(client: client), request.byteCount > maximum {
            continuation.finish(throwing: MediaFailure.uploadTooLarge(byteCount: request.byteCount, maximumByteCount: maximum))
            return
        }

        let (progressStream, watcher) = makeSDKStream(of: Double.self)

        let forwarding = Task {
            for await fraction in progressStream {
                continuation.yield(.progress(MediaUploadProgressInfo(fraction: fraction)))
            }
        }

        do {
            let mediaURI = try await client.uploadMedia(
                mimeType       : request.mimeType,
                data           : request.data,
                progressWatcher: watcher
            )

            forwarding.cancel()

            continuation.yield(.progress(.completed))
            continuation.yield(.finished(mediaURI: mediaURI))
            continuation.finish()
        } catch {
            forwarding.cancel()

            Log.media.error("Media upload failed: \(String(reflecting: error), privacy: .public)")

            continuation.finish(throwing: MediaFailure.uploadFailed(SDKErrorInfo(error)))
        }
    }

    private func maximumUploadSize(client: Client) async throws -> Int {
        if let cachedMaximumUploadSize {
            return cachedMaximumUploadSize
        }

        do {
            let size = Int(try await client.getMaxMediaUploadSize())

            cachedMaximumUploadSize = size

            return size
        } catch {
            throw MediaFailure.sdk(SDKErrorInfo(error))
        }
    }

    private func activeClient() throws -> Client {
        guard let client = clientService.sdkClient else {
            throw MediaFailure.noActiveClient
        }

        return client
    }

    /// Thumbnails of different sizes are different files, so the requested geometry belongs in the
    /// cache key alongside the media identity.
    private static func thumbnailKey(
        for item: MediaItem,
        width   : Int,
        height  : Int
    ) -> String {
        "\(item.cacheKey)-\(width)x\(height)"
    }

    /// One directory per media keeps the original file name intact without letting two attachments
    /// that happen to share a name collide.
    private static func makeDestination(name: String, key: String) throws -> URL {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw MediaFailure.fileUnavailable(reason: "The caches directory is unavailable.")
        }

        let directory = caches
            .appendingPathComponent("MediaFiles", isDirectory: true)
            .appendingPathComponent(key, isDirectory: true)

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )

        let destination = directory.appendingPathComponent(sanitized(name), isDirectory: false)

        try? FileManager.default.removeItem(at: destination)

        return destination
    }

    private static func sanitized(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")

        return cleaned.isEmpty ? "attachment" : cleaned
    }
}
