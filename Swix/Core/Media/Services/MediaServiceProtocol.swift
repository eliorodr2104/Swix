//
//  MediaServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Uploads and downloads media through the signed in client.
protocol MediaServiceProtocol {

    /// Uploads one file, reporting progress until the homeserver returns its mxc URI.
    ///
    /// The stream emits `progress` values and exactly one `finished` before completing, or throws
    /// a `MediaFailure`. Cancelling the consuming task cancels the transfer.
    func upload(request: MediaUploadRequest) -> AsyncThrowingStream<MediaUploadEvent, any Error>

    /// Downloads and, for an encrypted room, decrypts the full media behind `item`.
    func content(for item: MediaItem) async throws -> Data

    /// Downloads a server generated thumbnail, going through the disk cache first.
    func thumbnail(for item: MediaItem, width: Int, height: Int) async throws -> Data

    /// Downloads the media into a file the caller can hand to a share sheet or a player.
    ///
    /// The returned URL stays valid until `releaseFile(at:)` is called for it.
    func file(for item: MediaItem, filename: String?) async throws -> URL

    /// The largest upload the homeserver accepts, in bytes.
    func maxUploadSize() async throws -> Int

    /// Releases a file previously handed out by `file(for:filename:)`.
    func releaseFile(at url: URL)

    /// Releases every file handle still held. Called once, when the session ends.
    func shutdown()
}
