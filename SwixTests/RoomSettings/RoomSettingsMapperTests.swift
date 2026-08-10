//
//  RoomSettingsMapperTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Testing
@testable import Swix


@Suite("RoomSettingsMapper")
struct RoomSettingsMapperTests {

    @Test("every join rule this app supports round trips through the SDK shape")
    func joinRuleRoundTrips() {
        let pairs: [(JoinRuleSetting, JoinRule)] = [
            (.public, .public),
            (.invite, .invite),
            (.knock, .knock),
            (.restricted(roomIDs: ["!a:example.org"]), .restricted(rules: [.roomMembership(roomId: "!a:example.org")])),
            (.knockRestricted(roomIDs: ["!a:example.org"]), .knockRestricted(rules: [.roomMembership(roomId: "!a:example.org")]))
        ]

        for (setting, sdkRule) in pairs {
            #expect(RoomSettingsMapper.makeSDKJoinRule(from: setting) == sdkRule)
            #expect(RoomSettingsMapper.makeJoinRuleSetting(from: sdkRule) == setting)
        }
    }

    @Test("private and custom join rules map to nil, since this app offers no case for either")
    func unsupportedJoinRulesMapToNil() {
        #expect(RoomSettingsMapper.makeJoinRuleSetting(from: .private) == nil)
        #expect(RoomSettingsMapper.makeJoinRuleSetting(from: .custom(repr: "org.example.custom")) == nil)
    }

    @Test("a nil join rule maps to nil")
    func nilJoinRuleMapsToNil() {
        #expect(RoomSettingsMapper.makeJoinRuleSetting(from: nil) == nil)
    }

    @Test("a restricted rule drops any allow rule this app cannot represent")
    func restrictedRuleDropsUnrepresentableAllowRules() {
        let sdkRule = JoinRule.restricted(rules: [
            .roomMembership(roomId: "!a:example.org"),
            .custom(json: "{}")
        ])

        #expect(RoomSettingsMapper.makeJoinRuleSetting(from: sdkRule) == .restricted(roomIDs: ["!a:example.org"]))
    }

    @Test("every history visibility round trips through the SDK shape")
    func historyVisibilityRoundTrips() {
        let pairs: [(HistoryVisibilitySetting, RoomHistoryVisibility)] = [
            (.invited, .invited),
            (.joined, .joined),
            (.shared, .shared),
            (.worldReadable, .worldReadable)
        ]

        for (setting, sdkVisibility) in pairs {
            #expect(RoomSettingsMapper.makeSDKHistoryVisibility(from: setting) == sdkVisibility)
            #expect(RoomSettingsMapper.makeHistoryVisibilitySetting(from: sdkVisibility) == setting)
        }
    }

    @Test("a custom history visibility maps to nil")
    func customHistoryVisibilityMapsToNil() {
        #expect(RoomSettingsMapper.makeHistoryVisibilitySetting(from: .custom(value: "org.example.custom")) == nil)
    }

    @Test("room visibility maps public and private straight across")
    func roomVisibilityMapsDirectly() {
        #expect(RoomSettingsMapper.makeSDKVisibility(from: .public) == .public)
        #expect(RoomSettingsMapper.makeSDKVisibility(from: .private) == .private)
        #expect(RoomSettingsMapper.makeVisibilitySetting(from: .public) == .public)
        #expect(RoomSettingsMapper.makeVisibilitySetting(from: .private) == .private)
    }

    @Test("a custom room visibility is treated as private, the safer assumption")
    func customRoomVisibilityIsTreatedAsPrivate() {
        #expect(RoomSettingsMapper.makeVisibilitySetting(from: .custom(value: "org.example.custom")) == .private)
    }
}
