//
//  LiveLocationRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing
@testable import Swix


@Suite("LiveLocationRepository")
struct LiveLocationRepositoryTests {

    @Test("start() attaches the own-beacon listener and this room's live shares")
    func startAttachesBothStreams() async {
        let service = MockLocationService()
        let repository = LiveLocationRepository(roomID: "!room:example.org", service: service)

        await repository.start()

        #expect(service.startCallCount == 1)
        #expect(repository.failure == nil)
    }

    @Test("an own-beacon update for this room updates isSharingOwn")
    func ownBeaconUpdateForThisRoomUpdatesFlag() async {
        let service = MockLocationService()
        let repository = LiveLocationRepository(roomID: "!room:example.org", service: service)

        await repository.start()

        service.ownBeaconContinuation.yield(OwnBeaconShareUpdate(roomID: "!room:example.org", eventID: "$e1", isLive: true))

        await Eventually.isTrue { repository.isSharingOwn }

        #expect(repository.isSharingOwn)
    }

    @Test("an own-beacon update for a different room is ignored")
    func ownBeaconUpdateForOtherRoomIsIgnored() async {
        let service = MockLocationService()
        let repository = LiveLocationRepository(roomID: "!room:example.org", service: service)

        await repository.start()

        service.ownBeaconContinuation.yield(OwnBeaconShareUpdate(roomID: "!other:example.org", eventID: "$e1", isLive: true))

        // Give the observer a moment to have processed the update, if it were going to.
        try? await Task.sleep(for: .milliseconds(50))

        #expect(repository.isSharingOwn == false)
    }

    @Test("live share diffs from the service are applied to activeShares")
    func liveShareDiffsAreApplied() async {
        let service = MockLocationService()
        let repository = LiveLocationRepository(roomID: "!room:example.org", service: service)

        await repository.start()

        let share = LiveLocationShare(
            userID   : "@alice:example.org",
            lastKnown: nil,
            expiresAt: Date().addingTimeInterval(300)
        )

        service.liveShareContinuation(forRoom: "!room:example.org")?.yield([.reset([share])])

        await Eventually.isTrue { !repository.activeShares.isEmpty }

        #expect(repository.activeShares.map(\.userID) == ["@alice:example.org"])
    }

    @Test("startLiveShare forwards to the service with this room's id")
    func startLiveShareForwardsRoomID() async {
        let service = MockLocationService()
        let repository = LiveLocationRepository(roomID: "!room:example.org", service: service)

        await repository.startLiveShare(duration: 600)

        #expect(service.startLiveShareCalls.first?.roomID == "!room:example.org")
        #expect(service.startLiveShareCalls.first?.duration == 600)
    }

    @Test("a failed send records the failure")
    func failedSendRecordsFailure() async {
        let service = MockLocationService()

        service.sendError = LocationFailure.sendFailed(Fixtures.sdkErrorInfo())

        let repository = LiveLocationRepository(roomID: "!room:example.org", service: service)

        await repository.sendStaticLocation(LocationPayload(latitude: 1, longitude: 2))

        #expect(repository.failure != nil)
    }

    @Test("a service that cannot attach live shares surfaces the failure, and can retry later")
    func liveSharesFailureCanRetry() async {
        let service = MockLocationService()

        service.liveSharesError = LocationFailure.roomUnavailable(Fixtures.sdkErrorInfo())

        let repository = LiveLocationRepository(roomID: "!room:example.org", service: service)

        await repository.start()

        #expect(repository.failure != nil)

        service.liveSharesError = nil

        await repository.start()

        #expect(repository.failure == nil)
    }

    @Test("shutdown releases this room from the service")
    func shutdownReleasesRoom() {
        let service = MockLocationService()
        let repository = LiveLocationRepository(roomID: "!room:example.org", service: service)

        repository.shutdown()

        #expect(service.releasedRooms == ["!room:example.org"])
    }
}
