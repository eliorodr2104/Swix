//
//  SyncStateMapperTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
import MatrixRustSDK
@testable import Swix


@Suite("SyncStateMapper")
struct SyncStateMapperTests {

    @Test(
        "makeSyncState maps every SDK case to its domain equivalent, error included",
        arguments: [
            (SyncServiceState.idle, SyncState.idle),
            (SyncServiceState.running, SyncState.running),
            (SyncServiceState.terminated, SyncState.terminated),
            (SyncServiceState.offline, SyncState.offline),
            (SyncServiceState.error, SyncState.failed)
        ]
    )
    func makeSyncStateMapsEveryCase(
        sdkState: SyncServiceState,
        expected: SyncState
    ) {

        #expect(SyncStateMapper.makeSyncState(from: sdkState) == expected)
    }

    @Test(
        "makeSyncIndicatorState maps the debounced show/hide signal",
        arguments: [
            (RoomListServiceSyncIndicator.show, SyncIndicatorState.visible),
            (RoomListServiceSyncIndicator.hide, SyncIndicatorState.hidden)
        ]
    )
    func makeSyncIndicatorStateMapsEveryCase(
        sdkIndicator: RoomListServiceSyncIndicator,
        expected    : SyncIndicatorState
    ) {

        #expect(SyncStateMapper.makeSyncIndicatorState(from: sdkIndicator) == expected)
    }
}
