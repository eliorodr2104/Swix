//
//  RoomVisibilitySetting.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// SDK-free mirror of `MatrixRustSDK.RoomVisibility`, minus its `custom` escape hatch: whether the
/// room is published in the homeserver's public room directory, distinct from its join rule.
enum RoomVisibilitySetting: Equatable {

    /// The room is shown in the homeserver's published room directory.
    case `public`

    /// The room is not shown in the homeserver's published room directory.
    case `private`
}
