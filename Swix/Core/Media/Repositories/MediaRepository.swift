//
//  MediaRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Observation
import os


/// The observable face of media work: it drives `MediaService` and publishes upload progress.
///
/// Downloads stay plain `async` calls returning optionals, because a view that needs an image asks
/// for it once and either gets it or does not; only uploads have a lifetime worth observing.
@Observable
final class MediaRepository {

    /// Progress of every upload the app started, keyed by `MediaUploadRequest.id`.
    private(set) var uploads: [UUID: MediaUploadState] = [:]

    /// The last failure any operation raised, kept until the next one clears it.
    private(set) var failure: MediaFailure?

    @ObservationIgnored
    private let mediaService: any MediaServiceProtocol

    @ObservationIgnored
    private var uploadTasks: [UUID: Task<String?, Never>] = [:]

    init(mediaService: any MediaServiceProtocol) {
        self.mediaService = mediaService
    }

    /// Uploads `request`, publishing its progress while it runs, and returns the mxc URI.
    ///
    /// The work runs in a task the repository keeps, so `cancelUpload(_:)` can stop it even though
    /// the caller is the one awaiting the result.
    @discardableResult
    func upload(_ request: MediaUploadRequest) async -> String? {
        uploads[request.id] = .uploading(.started)
        failure = nil

        let task = Task { [weak self] in
            await self?.consumeUpload(request) ?? nil
        }

        uploadTasks[request.id] = task

        let mediaURI = await task.value

        uploadTasks[request.id] = nil

        return mediaURI
    }

    /// Stops a running upload and forgets its progress.
    func cancelUpload(_ id: UUID) {
        uploadTasks[id]?.cancel()
        uploadTasks[id] = nil
        uploads[id] = nil
    }

    /// Progress of one tracked upload, for a view bound to a single attachment.
    func progress(for id: UUID) -> MediaUploadProgressInfo? {
        uploads[id]?.progress
    }

    /// Forgets a finished upload, so a list of attachments does not keep growing.
    func clearUpload(_ id: UUID) {
        uploads[id] = nil
    }

    /// Full media bytes, or nil once the failure has been published.
    func content(for item: MediaItem) async -> Data? {
        await perform { try await mediaService.content(for: item) }
    }

    /// Server generated thumbnail bytes, or nil once the failure has been published.
    func thumbnail(for item: MediaItem, width: Int, height: Int) async -> Data? {
        await perform { try await mediaService.thumbnail(for: item, width: width, height: height) }
    }

    /// A file URL valid until `releaseFile(at:)` is called, or nil once the failure is published.
    func file(for item: MediaItem, filename: String? = nil) async -> URL? {
        await perform { try await mediaService.file(for: item, filename: filename) }
    }

    /// Tells the service the caller is done with a file it handed out.
    func releaseFile(at url: URL) {
        mediaService.releaseFile(at: url)
    }

    /// The homeserver's upload limit in bytes, or nil once the failure has been published.
    func maximumUploadSize() async -> Int? {
        await perform { try await mediaService.maxUploadSize() }
    }

    /// Cancels every running upload and releases the service's file handles. Called once, by the
    /// scope that created this repository, when the session ends.
    func shutdown() {
        for task in uploadTasks.values {
            task.cancel()
        }

        uploadTasks.removeAll()
        uploads.removeAll()

        mediaService.shutdown()
    }

    /// Drains the service's upload stream into `uploads`, translating a thrown failure into the
    /// same `.failed` state a view already knows how to render.
    private func consumeUpload(_ request: MediaUploadRequest) async -> String? {
        var mediaURI: String?

        do {
            for try await event in mediaService.upload(request: request) {
                switch event {
                    case .progress(let info): uploads[request.id] = .uploading(info)
                    case .finished(let uri):
                        mediaURI = uri
                        uploads[request.id] = .uploaded(mediaURI: uri)
                }
            }
        } catch {
            let mediaFailure = error as? MediaFailure ?? .uploadFailed(SDKErrorInfo(error))

            Log.media.error("Upload failed: \(String(reflecting: error), privacy: .public)")

            uploads[request.id] = .failed(message: mediaFailure.message)
            failure = mediaFailure

            return nil
        }

        // A cancelled stream simply ends, so the tracked entry has to be cleared here rather than
        // being left showing the progress it had reached when the user changed their mind.
        if Task.isCancelled {
            uploads[request.id] = nil
        }

        return mediaURI
    }

    /// Shared success/failure plumbing for the plain `async` download calls: publishes the
    /// failure on throw and clears it on success, so every call site stays a one-liner.
    private func perform<Value>(_ work: () async throws -> Value) async -> Value? {
        do {
            let value = try await work()

            failure = nil

            return value
        } catch {
            let mediaFailure = error as? MediaFailure ?? .sdk(SDKErrorInfo(error))

            Log.media.error("Media operation failed: \(String(reflecting: error), privacy: .public)")

            failure = mediaFailure

            return nil
        }
    }
}
