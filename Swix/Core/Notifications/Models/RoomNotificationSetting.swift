//
//  RoomNotificationSetting.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// A single room's effective notification mode, and where that mode comes from.
struct RoomNotificationSetting: Equatable {

    /// The mode currently in force for the room.
    let mode: NotificationMode

    /// Whether the mode is inherited from the account default rather than set on the room itself.
    /// Restoring the default is only meaningful when this is false.
    let isDefault: Bool

    init(
        mode     : NotificationMode,
        isDefault: Bool
    ) {
        self.mode      = mode
        self.isDefault = isDefault
    }
}
