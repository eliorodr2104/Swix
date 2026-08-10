//
//  SyncCoordinatorProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Owns the SDK sync engine for the lifetime of one signed in session.
protocol SyncCoordinatorProtocol: RoomProviding {

    /// Lifecycle of the sync engine, mapped out of the SDK's own state machine.
    var stateStream: AsyncStream<SyncState> { get }

    /// Debounced "still syncing" signal for the room list.
    var indicatorStream: AsyncStream<SyncIndicatorState> { get }

    /// Builds the sync service on first call, then starts or resumes it.
    func start() async throws

    /// Pauses sync without tearing down the service or its listeners, so a later `start()` resumes
    /// instantly instead of rebuilding everything.
    func stop() async

    /// The room list service backing this session, for features that page or filter rooms.
    func roomListService() throws -> RoomListService

    /// Releases every subscription this coordinator owns. Called once, when the session ends.
    func shutdown()
}
