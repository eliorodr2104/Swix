//
//  OwnProfileRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing
@testable import Swix


@Suite("OwnProfileRepository")
struct OwnProfileRepositoryTests {

    @Test("start() observes the profile stream and loads the current profile")
    func startLoadsProfile() async {
        let service = MockProfileService()
        let repository = OwnProfileRepository(profileService: service)

        await repository.start()

        #expect(repository.profile == service.stubbedOwnProfile)
        #expect(service.startObservingCallCount == 1)
        #expect(repository.failure == nil)
    }

    @Test("a later push update replaces the cached profile")
    func laterUpdateReplacesProfile() async {
        let service = MockProfileService()
        let repository = OwnProfileRepository(profileService: service)

        await repository.start()

        let updated = UserProfileInfo(userID: "@alice:example.org", displayName: "Alice Cooper", avatarURL: nil, status: nil, isInCall: false)

        service.ownProfileContinuation.yield(updated)

        await Eventually.isTrue { repository.profile?.displayName == "Alice Cooper" }

        #expect(repository.profile == updated)
    }

    @Test("updateDisplayName toggles isBusy around the call and clears on success")
    func updateDisplayNameTogglesBusy() async {
        let service = MockProfileService()
        let repository = OwnProfileRepository(profileService: service)

        await repository.updateDisplayName("New Name")

        #expect(service.setDisplayNameCalls == ["New Name"])
        #expect(repository.isBusy == false)
        #expect(repository.failure == nil)
    }

    @Test("a failed avatar upload records the failure")
    func failedAvatarUploadRecordsFailure() async {
        let service = MockProfileService()

        service.writeError = UsersFailure.sdk(Fixtures.sdkErrorInfo())

        let repository = OwnProfileRepository(profileService: service)

        await repository.updateAvatar(data: Data([0x1, 0x2]), mimeType: "image/png")

        #expect(repository.failure != nil)
        #expect(service.uploadAvatarCalls.count == 1)
    }

    @Test("observing the stream twice only subscribes once")
    func observingTwiceSubscribesOnce() async {
        let service = MockProfileService()
        let repository = OwnProfileRepository(profileService: service)

        await repository.start()
        await repository.start()

        #expect(service.startObservingCallCount == 1)
    }

    @Test("shutdown releases the service")
    func shutdownReleasesService() {
        let service = MockProfileService()
        let repository = OwnProfileRepository(profileService: service)

        repository.shutdown()

        #expect(service.shutdownCallCount == 1)
    }
}
