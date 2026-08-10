//
//  HistoryVisibilitySetting.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// SDK-free mirror of `MatrixRustSDK.RoomHistoryVisibility`, minus its `custom` escape hatch:
/// nothing in this app lets someone pick an unrecognised visibility, so there is nothing here for
/// it to round trip to.
enum HistoryVisibilitySetting: Equatable {

    /// Previous events are accessible to newly joined members from the point they were invited.
    case invited

    /// Previous events are accessible to newly joined members from the point they joined.
    case joined

    /// Previous events are always accessible to newly joined members, even ones sent before they
    /// were in the room.
    case shared

    /// Every event is readable by anyone, member or not, on any participating homeserver.
    case worldReadable
}
