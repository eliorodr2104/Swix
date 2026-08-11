//
//  MatrixImagePhase.swift
//  Swix
//
//  Created by Eliomar on 11/08/2026.
//

import SwiftUI


/// Where a `MatrixImage` load stands, handed to the caller's content builder so every rendering
/// decision stays in their hands.
enum MatrixImagePhase {

    /// The download is still on its way, or has not started yet.
    case empty

    /// The media arrived and decoded; this is the image to show.
    case success(Image)

    /// The media could not be fetched or decoded, and retrying without anything changing would
    /// fail the same way. Fallbacks like monogram avatars belong on this case.
    case failure
}
