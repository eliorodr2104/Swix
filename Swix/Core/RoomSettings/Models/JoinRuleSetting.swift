//
//  JoinRuleSetting.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// SDK-free mirror of `MatrixRustSDK.JoinRule`, minus its `custom` and `private` escape hatches:
/// nothing in this app lets someone pick an unrecognised join rule, so there is nothing here for
/// either one to round trip to.
enum JoinRuleSetting: Equatable {

    /// Anyone can join the room without any prior action.
    case `public`

    /// A user must first receive an invite from someone already inside the room.
    case invite

    /// Users can join if invited, or ask to be invited.
    case knock

    /// Users can join if invited, or if they belong to one of the rooms in `roomIDs`.
    case restricted(roomIDs: [String])

    /// Combines `restricted` and `knock`: invited, a member of one of `roomIDs`, or asking to be
    /// invited.
    case knockRestricted(roomIDs: [String])
}
