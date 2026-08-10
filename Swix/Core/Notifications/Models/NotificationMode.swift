//
//  NotificationMode.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// How loudly a room notifies, in Core's own vocabulary.
///
/// Named apart from the SDK's `RoomNotificationMode` on purpose: the two shapes meet only inside
/// `RoomNotificationSettingMapper`, so a rename upstream fails to compile there and nowhere else.
enum NotificationMode: Equatable, CaseIterable {

    /// Every message in the room raises a notification.
    case allMessages

    /// Only mentions and keyword matches raise a notification.
    case mentionsAndKeywords

    /// The room never notifies.
    case mute
}
