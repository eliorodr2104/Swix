//
//  MediaUploadProgressInfo.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// How far an upload has got, as a fraction a progress view can bind to directly.
struct MediaUploadProgressInfo: Equatable {

    /// Completed share of the transfer, always inside zero and one.
    let fraction: Double

    /// Clamps out of range values, since a transport that reports more bytes sent than the total
    /// would otherwise drive a progress view past its track.
    init(fraction: Double) {
        self.fraction = min(max(fraction, 0), 1)
    }

    /// The state every upload begins in, before the first byte is acknowledged.
    static let started = MediaUploadProgressInfo(fraction: 0)

    /// The state an upload ends in once the homeserver has the whole file.
    static let completed = MediaUploadProgressInfo(fraction: 1)

    /// Rounded percentage, for labels that show a number next to the bar.
    var percentage: Int { Int((fraction * 100).rounded()) }
}
