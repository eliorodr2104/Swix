//
//  MediaSourceMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Converts between the SDK's `MediaSource` handle and the domain's `MediaItem`.
enum MediaSourceMapper {

    /// Rebuilds the SDK handle a `MediaItem` was made from.
    static func makeMediaSource(from item: MediaItem) throws -> MediaSource {
        do {
            return try MediaSource.fromJson(json: item.sourceIdentifier)
        } catch {
            throw MediaFailure.invalidSource(reason: SDKErrorInfo(error).message)
        }
    }

    /// Captures an SDK handle as a domain value, so nothing downstream has to hold an FFI object.
    static func makeMediaItem(
        from source: MediaSource,
        mimeType   : String? = nil,
        filename   : String? = nil
    ) -> MediaItem {

        MediaItem(
            sourceIdentifier: source.toJson(),
            mediaURI        : source.url(),
            mimeType        : mimeType,
            filename        : filename
        )
    }

    /// Builds an item for unencrypted media, which an mxc URI alone fully describes.
    static func makeMediaItem(
        mediaURI: String,
        mimeType: String? = nil,
        filename: String? = nil
    ) throws -> MediaItem {

        do {
            return makeMediaItem(from: try MediaSource.fromUrl(url: mediaURI), mimeType: mimeType, filename: filename)
        } catch {
            throw MediaFailure.invalidSource(reason: SDKErrorInfo(error).message)
        }
    }
}
