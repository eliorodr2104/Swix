//
//  MatrixImageVariant.swift
//  Swix
//
//  Created by Eliomar on 11/08/2026.
//

import Foundation


/// Which rendition of the media a `MatrixImage` asks the homeserver for.
enum MatrixImageVariant: Equatable {

    /// A server side thumbnail of roughly the given size, in points. The right choice for
    /// avatars and grids: a fraction of the bytes, and the homeserver does the scaling.
    case thumbnail(CGSize)

    /// The full media as uploaded. For photo viewers and anything the user zooms into.
    case original
}
