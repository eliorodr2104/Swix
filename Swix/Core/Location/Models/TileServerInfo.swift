//
//  TileServerInfo.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// SDK-free mirror of `MatrixRustSDK.TileServerInfo`'s single field.
///
/// Kept here so a map screen never needs to import MatrixRustSDK just to read a style URL, the
/// same reasoning `OAuthClientMetadata` mirrors `OAuthConfiguration` for.
struct TileServerInfo: Equatable {

    /// The vector tile style document to hand the map renderer (MSC3488).
    let mapStyleUrl: String
}
