//
//  MockSyncCoordinator.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
@testable import Swix


/// A `SyncCoordinatorProtocol` double that records every call and lets a test push values through
/// its two streams on demand.
///
/// `roomListService()` and `room(withId:)` throw rather than fabricate an SDK `Room`: nothing under
/// `SyncRepository` calls either, so a graceful failure is enough to keep this double honest without
/// having to fake the one type the style guide says never to fake.
///
/// The conformance is spelled `@MainActor` because `SyncCoordinatorProtocol` inherits `RoomProviding`,
/// whose conformance the compiler infers as main actor isolated here; the composed conformance has to
/// say so out loud once it is written in a different module from the protocol.
final class MockSyncCoordinator: @MainActor SyncCoordinatorProtocol {

    let stateStream: AsyncStream<SyncState>

    let indicatorStream: AsyncStream<SyncIndicatorState>

    /// How many times `start()` was called.
    private(set) var startCallCount = 0

    /// How many times `stop()` was called.
    private(set) var stopCallCount = 0

    /// How many times `shutdown()` was called.
    private(set) var shutdownCallCount = 0

    /// What `start()` throws next time it is called, nil for a plain success.
    var startError: (any Error)?

    private let stateContinuation: AsyncStream<SyncState>.Continuation

    private let indicatorContinuation: AsyncStream<SyncIndicatorState>.Continuation

    init() {
        (stateStream, stateContinuation) = AsyncStream<SyncState>.makeStream(bufferingPolicy: .unbounded)
        (indicatorStream, indicatorContinuation) = AsyncStream<SyncIndicatorState>.makeStream(bufferingPolicy: .unbounded)
    }

    func start() async throws {
        startCallCount += 1

        if let startError {
            throw startError
        }
    }

    func stop() async {
        stopCallCount += 1
    }

    func roomListService() throws -> RoomListService {
        throw SyncFailure.notStarted
    }

    func room(withId roomID: String) throws -> Room {
        throw SyncFailure.notStarted
    }

    func shutdown() {
        shutdownCallCount += 1
    }

    /// Pushes one state update to whoever is observing `stateStream`.
    func emit(state: SyncState) {
        stateContinuation.yield(state)
    }

    /// Pushes one indicator update to whoever is observing `indicatorStream`.
    func emit(indicator: SyncIndicatorState) {
        indicatorContinuation.yield(indicator)
    }
}
