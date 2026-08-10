//
//  RoomNotificationSettingMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Translates between the SDK's push modes and the Core vocabulary the rest of the app reads.
enum RoomNotificationSettingMapper {

    /// Maps the SDK mode onto the domain one.
    static func makeMode(from mode: RoomNotificationMode) -> NotificationMode {
        switch mode {
            case .allMessages: .allMessages
            case .mentionsAndKeywordsOnly: .mentionsAndKeywords
            case .mute: .mute
        }
    }

    /// Maps the domain mode back onto the SDK one, for the setters.
    static func makeSDKMode(from mode: NotificationMode) -> RoomNotificationMode {
        switch mode {
            case .allMessages: .allMessages
            case .mentionsAndKeywords: .mentionsAndKeywordsOnly
            case .mute: .mute
        }
    }

    /// Maps a room's resolved settings, mode and provenance together.
    static func makeSetting(from settings: RoomNotificationSettings) -> RoomNotificationSetting {
        RoomNotificationSetting(mode: makeMode(from: settings.mode), isDefault: settings.isDefault)
    }
}
