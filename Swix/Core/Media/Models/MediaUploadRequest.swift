//
//  MediaUploadRequest.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// One file the user asked to send, described in full before any network work starts.
///
/// The identifier is generated locally so the UI can track progress of several concurrent uploads
/// before the homeserver has assigned any of them an mxc URI.
struct MediaUploadRequest: Equatable, Identifiable {

    /// Local tracking identifier, the key `MediaRepository` files progress under.
    let id: UUID

    /// The bytes to upload, already read into memory by whoever picked the file.
    let data: Data

    /// Content type sent to the homeserver, for example `image/jpeg`.
    let mimeType: String

    /// Name to show the recipient, when the source of the file had one.
    let filename: String?

    init(
        id      : UUID = UUID(),
        data    : Data,
        mimeType: String,
        filename: String? = nil
    ) {

        self.id = id
        self.data = data
        self.mimeType = mimeType
        self.filename = filename
    }

    /// Size of the payload, for checking it against the homeserver's upload limit.
    var byteCount: Int { data.count }
}
