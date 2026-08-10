//
//  RoomNotificationSettingMapperTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Testing
@testable import Swix


@Suite("RoomNotificationSettingMapper")
struct RoomNotificationSettingMapperTests {

    @Test("every SDK mode round trips through the domain mode")
    func modesRoundTrip() {
        let pairs: [(MatrixRustSDK.RoomNotificationMode, NotificationMode)] = [
            (.allMessages, .allMessages),
            (.mentionsAndKeywordsOnly, .mentionsAndKeywords),
            (.mute, .mute)
        ]

        for (sdkMode, domainMode) in pairs {
            #expect(RoomNotificationSettingMapper.makeMode(from: sdkMode) == domainMode)
            #expect(RoomNotificationSettingMapper.makeSDKMode(from: domainMode) == sdkMode)
        }
    }

    @Test("a resolved setting keeps its mode and its default provenance")
    func settingKeepsModeAndProvenance() {
        let resolved = RoomNotificationSettings(mode: .mentionsAndKeywordsOnly, isDefault: true)

        let setting = RoomNotificationSettingMapper.makeSetting(from: resolved)

        #expect(setting.mode == .mentionsAndKeywords)
        #expect(setting.isDefault == true)
    }
}
