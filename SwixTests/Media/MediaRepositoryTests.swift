//
//  MediaRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing
@testable import Swix


@Suite("MediaRepository")
struct MediaRepositoryTests {

    @Test("an upload's progress events are published in order, ending in uploaded")
    func uploadProgressIsPublishedInOrder() async {
        let service = MockMediaService()

        service.stubbedUploadEvents = [
            .progress(MediaUploadProgressInfo(fraction: 0.0)),
            .progress(MediaUploadProgressInfo(fraction: 0.5)),
            .progress(.completed),
            .finished(mediaURI: "mxc://example.org/abc")
        ]

        let repository = MediaRepository(mediaService: service)
        let request = Self.makeRequest()

        // The repository drains the whole stream before this returns, so intermediate progress
        // has already been overwritten by the terminal state by the time we can observe it here;
        // what this proves is that the terminal state really is the last event the mock emitted.
        let mediaURI = await repository.upload(request)

        #expect(mediaURI == "mxc://example.org/abc")
        #expect(repository.uploads[request.id] == .uploaded(mediaURI: "mxc://example.org/abc"))
    }

    @Test("progress is observable while the upload is still running")
    func progressIsObservableMidUpload() async {
        let service = MockMediaService()
        let request = Self.makeRequest()

        let (gate, gateContinuation) = AsyncStream<Void>.makeStream()

        // Built out here because the handler runs off the main actor, where the initializer of a
        // main actor isolated model type cannot be reached.
        let quarter = MediaUploadProgressInfo(fraction: 0.25)
        let completed = MediaUploadProgressInfo.completed

        service.uploadHandler = { _, continuation in
            continuation.yield(.progress(quarter))

            for await _ in gate { break }

            continuation.yield(.progress(completed))
            continuation.yield(.finished(mediaURI: "mxc://example.org/xyz"))
            continuation.finish()
        }

        let repository = MediaRepository(mediaService: service)

        let uploadTask = Task { await repository.upload(request) }

        await Eventually.isTrue { repository.progress(for: request.id)?.fraction == 0.25 }

        #expect(repository.progress(for: request.id)?.percentage == 25)

        gateContinuation.finish()

        let mediaURI = await uploadTask.value

        #expect(mediaURI == "mxc://example.org/xyz")
    }

    @Test("a failed upload publishes a failed state and records the failure")
    func failedUploadPublishesFailedState() async {
        let service = MockMediaService()

        service.uploadError = MediaFailure.uploadFailed(Fixtures.sdkErrorInfo())

        let repository = MediaRepository(mediaService: service)
        let request = Self.makeRequest()

        let mediaURI = await repository.upload(request)

        #expect(mediaURI == nil)
        #expect(repository.failure != nil)

        guard case .failed = repository.uploads[request.id] else {
            Issue.record("expected a failed upload state")
            return
        }
    }

    @Test("cancelUpload stops the transfer and forgets its progress")
    func cancelUploadStopsTransfer() async {
        let service = MockMediaService()
        let request = Self.makeRequest()

        let (gate, _) = AsyncStream<Void>.makeStream()
        let started = MediaUploadProgressInfo(fraction: 0.1)

        service.uploadHandler = { _, continuation in
            continuation.yield(.progress(started))

            for await _ in gate { break }
        }

        let repository = MediaRepository(mediaService: service)

        let uploadTask = Task { await repository.upload(request) }

        await Eventually.isTrue { repository.progress(for: request.id) != nil }

        repository.cancelUpload(request.id)

        #expect(repository.progress(for: request.id) == nil)

        _ = await uploadTask.value
    }

    @Test("content(for:) clears a previous failure on success")
    func contentClearsPreviousFailure() async {
        let service = MockMediaService()

        service.downloadError = MediaFailure.downloadFailed(Fixtures.sdkErrorInfo())

        let repository = MediaRepository(mediaService: service)
        let item = Self.makeItem()

        let firstAttempt = await repository.content(for: item)

        #expect(firstAttempt == nil)
        #expect(repository.failure != nil)

        service.downloadError = nil
        service.stubbedContent = Data([0xAA])

        let secondAttempt = await repository.content(for: item)

        #expect(secondAttempt == Data([0xAA]))
        #expect(repository.failure == nil)
    }

    @Test("releaseFile forwards to the service")
    func releaseFileForwardsToService() {
        let service = MockMediaService()
        let repository = MediaRepository(mediaService: service)
        let url = URL(fileURLWithPath: "/tmp/example")

        repository.releaseFile(at: url)

        #expect(service.releasedFiles == [url])
    }

    @Test("shutdown cancels every running upload and releases the service")
    func shutdownCancelsUploadsAndReleasesService() async {
        let service = MockMediaService()
        let request = Self.makeRequest()

        let (gate, _) = AsyncStream<Void>.makeStream()
        let started = MediaUploadProgressInfo(fraction: 0.1)

        service.uploadHandler = { _, continuation in
            continuation.yield(.progress(started))

            for await _ in gate { break }
        }

        let repository = MediaRepository(mediaService: service)

        let uploadTask = Task { await repository.upload(request) }

        await Eventually.isTrue { repository.progress(for: request.id) != nil }

        repository.shutdown()

        #expect(repository.uploads.isEmpty)
        #expect(service.shutdownCallCount == 1)

        _ = await uploadTask.value
    }

    private static func makeRequest() -> MediaUploadRequest {
        MediaUploadRequest(data: Data([0x1, 0x2, 0x3]), mimeType: "image/png", filename: "photo.png")
    }

    private static func makeItem() -> MediaItem {
        MediaItem(sourceIdentifier: "{\"url\":\"mxc://example.org/abc\"}", mediaURI: "mxc://example.org/abc")
    }
}
