//
//  MockCallWidgetService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

@testable import Swix


/// Records every call `CallRepository` makes and lets a test push a "the driver stopped on its
/// own" event through `callEndedContinuation` whenever it wants.
final class MockCallWidgetService: CallWidgetServiceProtocol {

    let callEndedEvents: AsyncStream<Void>

    let callEndedContinuation: AsyncStream<Void>.Continuation

    var hasActiveCallResult = false

    private(set) var hasActiveCallRoomIDs: [String] = []

    var prepareCallResult: Result<CallSession, any Error> = .failure(CallFailure.noActiveClient)

    private(set) var prepareCallArgs: [(roomID: String, configuration: CallWidgetConfiguration)] = []

    private(set) var endCallCallCount = 0

    init() {
        (callEndedEvents, callEndedContinuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .unbounded)
    }

    func hasActiveCall(inRoom roomID: String) -> Bool {
        hasActiveCallRoomIDs.append(roomID)

        return hasActiveCallResult
    }

    func prepareCall(
        roomID       : String,
        configuration: CallWidgetConfiguration
    ) async throws -> CallSession {

        prepareCallArgs.append((roomID, configuration))

        return try prepareCallResult.get()
    }

    func endCall() async {
        endCallCallCount += 1
    }
}
