//
//  MockMediaService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
@testable import Swix


/// Records every call `MediaRepository` makes. `uploadHandler`, when set, gives a test full
/// control over what an upload's stream emits and when; otherwise `upload` answers with the
/// `stubbedUploadEvents` in order.
final class MockMediaService: MediaServiceProtocol {

    private(set) var uploadRequests: [MediaUploadRequest] = []

    private(set) var contentRequests: [MediaItem] = []

    private(set) var thumbnailRequests: [(item: MediaItem, width: Int, height: Int)] = []

    private(set) var fileRequests: [MediaItem] = []

    private(set) var releasedFiles: [URL] = []

    private(set) var shutdownCallCount = 0

    var stubbedUploadEvents: [MediaUploadEvent] = [.progress(.completed), .finished(mediaURI: "mxc://example.org/abc")]

    var uploadError: (any Error)?

    var uploadHandler: (@Sendable (MediaUploadRequest, AsyncThrowingStream<MediaUploadEvent, any Error>.Continuation) async -> Void)?

    var stubbedContent: Data = Data([0x1])

    var stubbedThumbnail: Data = Data([0x2])

    var stubbedFileURL: URL = URL(fileURLWithPath: "/tmp/stub-file")

    var stubbedMaxUploadSize = 50 * 1024 * 1024

    var downloadError: (any Error)?

    var maxSizeError: (any Error)?

    func upload(request: MediaUploadRequest) -> AsyncThrowingStream<MediaUploadEvent, any Error> {
        uploadRequests.append(request)

        return AsyncThrowingStream { continuation in
            let task = Task { [uploadHandler, stubbedUploadEvents, uploadError] in
                if let uploadHandler {
                    await uploadHandler(request, continuation)

                    return
                }

                for event in stubbedUploadEvents {
                    continuation.yield(event)
                }

                if let uploadError {
                    continuation.finish(throwing: uploadError)
                } else {
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func content(for item: MediaItem) async throws -> Data {
        contentRequests.append(item)

        if let downloadError {
            throw downloadError
        }

        return stubbedContent
    }

    func thumbnail(
        for item: MediaItem,
        width   : Int,
        height  : Int
    ) async throws -> Data {

        thumbnailRequests.append((item, width, height))

        if let downloadError {
            throw downloadError
        }

        return stubbedThumbnail
    }

    func file(for item: MediaItem, filename: String?) async throws -> URL {
        fileRequests.append(item)

        if let downloadError {
            throw downloadError
        }

        return stubbedFileURL
    }

    func maxUploadSize() async throws -> Int {
        if let maxSizeError {
            throw maxSizeError
        }

        return stubbedMaxUploadSize
    }

    func releaseFile(at url: URL) {
        releasedFiles.append(url)
    }

    func shutdown() {
        shutdownCallCount += 1
    }
}
