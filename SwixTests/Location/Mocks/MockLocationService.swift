//
//  MockLocationService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
@testable import Swix


/// Records every call `LiveLocationRepository` makes, and lets a test push own-beacon updates and
/// live-share diffs through at will. `liveShares(forRoom:)` hands back the same stream on repeated
/// calls for the same room, mirroring the real service's one-observer-per-room contract.
final class MockLocationService: LocationServiceProtocol {

    let ownBeaconUpdates: AsyncStream<OwnBeaconShareUpdate>

    let ownBeaconContinuation: AsyncStream<OwnBeaconShareUpdate>.Continuation

    private(set) var startCallCount = 0

    private(set) var sendStaticLocationCalls: [(roomID: String, payload: LocationPayload)] = []

    private(set) var startLiveShareCalls: [(roomID: String, duration: TimeInterval)] = []

    private(set) var updateLiveShareCalls: [(roomID: String, payload: LocationPayload)] = []

    private(set) var stopLiveShareCalls: [String] = []

    private(set) var releasedRooms: [String] = []

    private(set) var shutdownCallCount = 0

    var startError: (any Error)?

    var sendError: (any Error)?

    var shareError: (any Error)?

    var liveSharesError: (any Error)?

    var stubbedTileServer: TileServerInfo?

    private var liveShareStreams: [String: (
        stream: AsyncStream<[CollectionDiff<LiveLocationShare>]>,
        continuation: AsyncStream<[CollectionDiff<LiveLocationShare>]>.Continuation
    )] = [:]

    init() {
        (ownBeaconUpdates, ownBeaconContinuation) = AsyncStream<OwnBeaconShareUpdate>.makeStream(bufferingPolicy: .unbounded)
    }

    func start() throws {
        startCallCount += 1

        if let startError {
            throw startError
        }
    }

    func sendStaticLocation(
        roomID : String,
        payload: LocationPayload
    ) async throws {

        sendStaticLocationCalls.append((roomID, payload))

        if let sendError {
            throw sendError
        }
    }

    func startLiveShare(
        roomID  : String,
        duration: TimeInterval
    ) async throws -> String {

        startLiveShareCalls.append((roomID, duration))

        if let shareError {
            throw shareError
        }

        return "$beacon-event-id"
    }

    func updateLiveShare(
        roomID : String,
        payload: LocationPayload
    ) async throws {

        updateLiveShareCalls.append((roomID, payload))

        if let sendError {
            throw sendError
        }
    }

    func stopLiveShare(roomID: String) async throws {
        stopLiveShareCalls.append(roomID)

        if let shareError {
            throw shareError
        }
    }

    func liveShares(forRoom roomID: String) async throws -> AsyncStream<[CollectionDiff<LiveLocationShare>]> {
        if let liveSharesError {
            throw liveSharesError
        }

        if let existing = liveShareStreams[roomID] {
            return existing.stream
        }

        let pair = AsyncStream<[CollectionDiff<LiveLocationShare>]>.makeStream(bufferingPolicy: .unbounded)

        liveShareStreams[roomID] = pair

        return pair.stream
    }

    /// Test-only access to the continuation `liveShares(forRoom:)` created, so a test can push
    /// diffs after the repository has subscribed.
    func liveShareContinuation(forRoom roomID: String) -> AsyncStream<[CollectionDiff<LiveLocationShare>]>.Continuation? {
        liveShareStreams[roomID]?.continuation
    }

    func tileServer() async -> TileServerInfo? {
        stubbedTileServer
    }

    func release(roomID: String) {
        releasedRooms.append(roomID)
        liveShareStreams[roomID] = nil
    }

    func shutdown() {
        shutdownCallCount += 1
    }
}
