//
//  MediaItem.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import CryptoKit
import Foundation


/// A downloadable piece of media, identified the way the homeserver identifies one.
///
/// `sourceIdentifier` is deliberately opaque: for an encrypted room the SDK's media source carries
/// the decryption keys alongside the mxc URI, so only the SDK may interpret it.
struct MediaItem: Equatable, Hashable, Identifiable {

    /// The SDK media source serialized as JSON, round tripping through `MediaSource.fromJson`.
    let sourceIdentifier: String

    /// The mxc URI this source points at, kept for logging and for stable equality.
    let mediaURI: String

    /// Content type declared by the event that carried this media, when it declared one.
    let mimeType: String?

    /// Original file name declared by the event that carried this media, when it declared one.
    let filename: String?

    /// Identity for SwiftUI's own diffing, which is the source identifier: two events pointing at
    /// the same encrypted media really are the same item to show.
    var id: String { sourceIdentifier }

    init(
        sourceIdentifier: String,
        mediaURI        : String,
        mimeType        : String? = nil,
        filename        : String? = nil
    ) {

        self.sourceIdentifier = sourceIdentifier
        self.mediaURI = mediaURI
        self.mimeType = mimeType
        self.filename = filename
    }

    /// Short, filesystem safe key for on disk caches.
    ///
    /// It hashes the source so neither the mxc URI nor any embedded key material ever appears in a
    /// file name a backup browser or a crash report might surface.
    var cacheKey: String {
        let digest = SHA256.hash(data: Data(sourceIdentifier.utf8))
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()

        return String(hex.prefix(32))
    }
}
