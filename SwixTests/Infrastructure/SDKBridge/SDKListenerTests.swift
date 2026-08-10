//
//  SDKListenerTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Testing
@testable import Swix


/// Covers the two contracts every consumer of `makeSDKStream` relies on: a value handed to
/// `emit(_:)` shows up on the paired stream, and the stream finishes once nothing retains the
/// listener anymore.
@Suite("SDKListener")
struct SDKListenerTests {

    @Test("emit publishes the value to the paired stream")
    func emitPublishesTheValue() async {
        let (stream, listener) = makeSDKStream(of: Int.self)

        listener.emit(42)

        let values = await StreamProbe.collect(from: stream, count: 1)

        #expect(values == [42])
    }

    @Test("emit preserves the order values were published in")
    func emitPreservesOrder() async {
        let (stream, listener) = makeSDKStream(of: Int.self)

        listener.emit(1)
        listener.emit(2)
        listener.emit(3)

        let values = await StreamProbe.collect(from: stream, count: 3)

        #expect(values == [1, 2, 3])
    }

    @Test("dropping the listener finishes the stream instead of leaving a consumer suspended")
    func droppingListenerFinishesStream() async {
        let stream = Self.makeStreamOfAnAlreadyDroppedListener()

        let streamFinished = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in stream {}

                return true
            }

            group.addTask {
                try? await Task.sleep(for: .seconds(1))

                return false
            }

            let result = await group.next() ?? false
            group.cancelAll()

            return result
        }

        #expect(streamFinished)
    }

    @Test("ClientDelegate callbacks are flattened into SDKClientEvent")
    func clientDelegateForwardsEvents() async {
        let (stream, listener) = makeSDKStream(of: SDKClientEvent.self)

        listener.didReceiveAuthError(isSoftLogout: true)
        listener.onBackgroundTaskErrorReport(
            taskName: "sync",
            error   : .panic(message: "boom", panicBacktrace: nil)
        )

        let events = await StreamProbe.collect(from: stream, count: 2)

        guard case .authError(let isSoftLogout) = events.first else {
            Issue.record("Expected the first event to be .authError")
            return
        }

        #expect(isSoftLogout)

        guard case .backgroundTaskError(let taskName, _) = events.last else {
            Issue.record("Expected the second event to be .backgroundTaskError")
            return
        }

        #expect(taskName == "sync")
    }

    /// Builds the stream and lets the listener fall out of scope before returning, so the only
    /// strong reference to it is gone by the time the caller gets the stream back.
    private static func makeStreamOfAnAlreadyDroppedListener() -> AsyncStream<Int> {
        let (stream, listener) = makeSDKStream(of: Int.self)
        _ = listener

        return stream
    }
}
