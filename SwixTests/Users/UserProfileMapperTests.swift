//
//  UserProfileMapperTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Testing
@testable import Swix


@Suite("UserProfileMapper")
struct UserProfileMapperTests {

    @Test("a profile with no status and no call maps to isInCall false and status nil")
    func plainProfileMaps() {
        let profile = UserProfile(userId: "@alice:example.org", displayName: "Alice", avatarUrl: nil, status: nil, call: nil)

        let info = UserProfileMapper.makeUserProfileInfo(from: profile)

        #expect(info.userID == "@alice:example.org")
        #expect(info.displayName == "Alice")
        #expect(info.status == nil)
        #expect(info.isInCall == false)
    }

    @Test("a profile with a call resolves isInCall to true")
    func profileWithCallResolvesIsInCall() {
        let profile = UserProfile(
            userId     : "@alice:example.org",
            displayName: nil,
            avatarUrl  : nil,
            status     : nil,
            call       : UserCall(callJoinedTs: nil)
        )

        let info = UserProfileMapper.makeUserProfileInfo(from: profile)

        #expect(info.isInCall == true)
    }

    @Test("a status resolves into its emoji and text")
    func statusResolvesEmojiAndText() {
        let profile = UserProfile(
            userId     : "@alice:example.org",
            displayName: nil,
            avatarUrl  : nil,
            status     : UserStatus(emoji: "🎉", text: "Celebrating"),
            call       : nil
        )

        let info = UserProfileMapper.makeUserProfileInfo(from: profile)

        #expect(info.status == UserStatusInfo(emoji: "🎉", text: "Celebrating"))
    }

    @Test("a domain status round trips back to the SDK shape")
    func domainStatusRoundTrips() {
        let status = UserStatusInfo(emoji: "🎉", text: "Celebrating")

        let sdkStatus = UserProfileMapper.makeSDKUserStatus(from: status)

        #expect(sdkStatus.emoji == "🎉")
        #expect(sdkStatus.text == "Celebrating")
    }
}
