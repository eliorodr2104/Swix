//
//  MediaUploadEvent.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// What an in flight upload reports as it runs.
///
/// A successful upload emits any number of `progress` values and exactly one `finished` before its
/// stream ends; a failed one ends by throwing instead.
enum MediaUploadEvent: Equatable {

    /// The transfer advanced.
    case progress(MediaUploadProgressInfo)

    /// The homeserver accepted the file and assigned it this mxc URI.
    case finished(mediaURI: String)
}
