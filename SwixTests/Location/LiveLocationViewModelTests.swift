//
//  LiveLocationViewModelTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing
@testable import Swix


@Suite("LiveLocationViewModel")
struct LiveLocationViewModelTests {

    @Test("isEmpty reflects whether anybody is currently sharing")
    func isEmptyReflectsActiveShares() async {
        let service = MockLocationService()
        let repository = LiveLocationRepository(roomID: "!room:example.org", service: service)
        let viewModel = LiveLocationViewModel(repository: repository)

        #expect(viewModel.isEmpty)

        await viewModel.start()

        service.liveShareContinuation(forRoom: "!room:example.org")?.yield([
            .reset([LiveLocationShare(userID: "@alice:example.org", lastKnown: nil, expiresAt: Date().addingTimeInterval(60))])
        ])

        await Eventually.isTrue { !viewModel.isEmpty }

        #expect(!viewModel.isEmpty)
    }

    @Test("a share failure surfaces with a titled, user facing message")
    func shareFailureBecomesUserFacing() async {
        let service = MockLocationService()

        service.shareError = LocationFailure.shareFailed(Fixtures.sdkErrorInfo(kind: .network))

        let repository = LiveLocationRepository(roomID: "!room:example.org", service: service)
        let viewModel = LiveLocationViewModel(repository: repository)

        await viewModel.startSharing(duration: 300)

        #expect(viewModel.failure?.title == "Could not update live sharing")
        #expect(viewModel.failure?.isRetryable == true)
    }

    @Test("shutdown releases the repository")
    func shutdownReleasesRepository() {
        let service = MockLocationService()
        let repository = LiveLocationRepository(roomID: "!room:example.org", service: service)
        let viewModel = LiveLocationViewModel(repository: repository)

        viewModel.shutdown()

        #expect(service.releasedRooms == ["!room:example.org"])
    }
}
