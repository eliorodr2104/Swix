//
//  MediaUploadState.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Where one tracked upload stands, as `MediaRepository` publishes it to the UI.
enum MediaUploadState: Equatable {

    /// The transfer is running and has reported this much progress.
    case uploading(MediaUploadProgressInfo)

    /// The transfer finished and the file lives at this mxc URI.
    case uploaded(mediaURI: String)

    /// The transfer failed, with text already safe to show.
    case failed(message: String)

    /// Progress to render, absent once the upload stopped running.
    var progress: MediaUploadProgressInfo? {
        switch self {
            case .uploading(let info): info
            case .uploaded, .failed: nil
        }
    }

    /// The resulting mxc URI, absent until the upload succeeds.
    var mediaURI: String? {
        switch self {
            case .uploaded(let mediaURI): mediaURI
            case .uploading, .failed: nil
        }
    }

    /// Whether this upload will produce no further updates.
    var isFinished: Bool {
        switch self {
            case .uploading: false
            case .uploaded, .failed: true
        }
    }
}
