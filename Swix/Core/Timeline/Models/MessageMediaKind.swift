//
//  MessageMediaKind.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// What kind of attachment a message carries, when it carries one.
///
/// This is a summary, not the attachment itself: the timeline only needs to know which shape of
/// bubble to draw, while downloading the media is the media feature's job.
enum MessageMediaKind: Equatable, Hashable {

    /// A still image, drawn inline as a thumbnail the reader can open full size.
    case image

    /// A video, drawn as a poster frame with a play affordance over it.
    case video

    /// An audio file sent as an attachment rather than recorded in the app.
    case audio

    /// An audio message recorded as a voice note, which most clients render with a waveform.
    case voice

    /// Anything with no richer preview than its name, size and type.
    case file

    /// Several attachments sent as one event.
    case gallery

    /// A shared place, drawn as a map preview rather than as an attachment row.
    case location

    /// An image from a sticker pack, drawn without a bubble around it.
    case sticker

    /// Whether this attachment is meant to be played rather than opened.
    var isPlayable: Bool {
        switch self {
            case .video, .audio, .voice: true
            case .image, .file, .gallery, .location, .sticker: false
        }
    }
}
