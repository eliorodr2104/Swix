//
//  CallRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing
@testable import Swix


@Suite("CallRepository")
struct CallRepositoryTests {

    @Test("hasActiveCall(inRoom:) reads straight through to the widget service")
    func hasActiveCallReadsThrough() {
        let service = MockCallWidgetService()
        service.hasActiveCallResult = true

        let repository = CallRepository(widgetService: service)

        #expect(repository.hasActiveCall(inRoom: "!room:example.org"))
        #expect(service.hasActiveCallRoomIDs == ["!room:example.org"])
    }

    @Test("startCall() starts a fresh call and becomes ready")
    func startCallSucceeds() async {
        let service = MockCallWidgetService()
        let (session, _) = Self.makeSession()
        service.prepareCallResult = .success(session)

        let repository = CallRepository(widgetService: service)

        await repository.startCall(roomID: "!room:example.org")

        #expect(repository.callState == .ready)
        #expect(repository.failure == nil)
        #expect(service.prepareCallArgs.first?.roomID == "!room:example.org")
        #expect(service.prepareCallArgs.first?.configuration.intent == .startCall)
    }

    @Test("startCall() joins rather than starts when the room already has a call")
    func startCallJoinsAnExistingCall() async {
        let service = MockCallWidgetService()
        service.hasActiveCallResult = true
        service.prepareCallResult = .success(Self.makeSession().session)

        let repository = CallRepository(widgetService: service)

        await repository.startCall(roomID: "!room:example.org")

        #expect(service.prepareCallArgs.first?.configuration.intent == .joinExisting)
    }

    @Test("startCall() records a failure and moves to failed")
    func startCallFailure() async {
        let service = MockCallWidgetService()
        service.prepareCallResult = .failure(CallFailure.roomUnavailable(Fixtures.sdkErrorInfo()))

        let repository = CallRepository(widgetService: service)

        await repository.startCall(roomID: "!room:example.org")

        #expect(repository.callState == .failed)
        #expect(repository.activeSession == nil)

        guard case .roomUnavailable = repository.failure else {
            Issue.record("Expected .roomUnavailable, got \(String(describing: repository.failure))")
            return
        }
    }

    @Test("startCall() is a no-op while a call is already being prepared or is live")
    func startCallIsNoOpWhileActive() async {
        let service = MockCallWidgetService()
        service.prepareCallResult = .success(Self.makeSession().session)

        let repository = CallRepository(widgetService: service)

        await repository.startCall(roomID: "!room:example.org")
        await repository.startCall(roomID: "!room:example.org")

        #expect(service.prepareCallArgs.count == 1)
    }

    @Test("postMessageFromWebView forwards to the session and marks the call ongoing on the first message")
    func postMessageForwardsAndMarksOngoing() async {
        let service = MockCallWidgetService()
        let recorder = Recorder()
        let (session, _) = Self.makeSession(postMessage: { message in
            await recorder.record(message)
            return true
        })
        service.prepareCallResult = .success(session)

        let repository = CallRepository(widgetService: service)
        await repository.startCall(roomID: "!room:example.org")

        let message = CallWidgetMessage(json: "{\"hello\":1}")!
        let accepted = await repository.postMessageFromWebView(message)

        #expect(accepted)
        #expect(repository.callState == .ongoing)
        #expect(await recorder.messages == [message])
    }

    @Test("postMessageFromWebView returns false while there is no active session")
    func postMessageWithoutSessionReturnsFalse() async {
        let repository = CallRepository(widgetService: MockCallWidgetService())

        let accepted = await repository.postMessageFromWebView(CallWidgetMessage(json: "{}")!)

        #expect(!accepted)
        #expect(repository.callState == .idle)
    }

    @Test("hangUp() ends the call through the widget service and clears the session")
    func hangUpEndsTheCall() async {
        let service = MockCallWidgetService()
        service.prepareCallResult = .success(Self.makeSession().session)

        let repository = CallRepository(widgetService: service)
        await repository.startCall(roomID: "!room:example.org")

        await repository.hangUp()

        #expect(service.endCallCallCount == 1)
        #expect(repository.activeSession == nil)
        #expect(repository.callState == .ended)
    }

    @Test("A driver that stops on its own is reported as the call having ended")
    func remoteCallEndedIsReported() async {
        let service = MockCallWidgetService()
        service.prepareCallResult = .success(Self.makeSession().session)

        let repository = CallRepository(widgetService: service)
        await repository.startCall(roomID: "!room:example.org")

        service.callEndedContinuation.yield(())

        await Eventually.isTrue { repository.callState == .ended }

        #expect(repository.callState == .ended)
        #expect(repository.activeSession == nil)
    }

    @Test("stop() stops reacting to the call having ended remotely")
    func stopStopsObservingCallEndedEvents() async {
        let service = MockCallWidgetService()
        service.prepareCallResult = .success(Self.makeSession().session)

        let repository = CallRepository(widgetService: service)
        await repository.startCall(roomID: "!room:example.org")

        // One event has to make it through before the observing task is cancelled, otherwise this
        // would not be testing cancellation at all: a value buffered before the loop's very first
        // iteration is handed over whatever the task's cancellation state. Starting a second call
        // then puts the repository back on ready, which is what the assertion below reads.
        service.callEndedContinuation.yield(())
        await Eventually.isTrue { repository.callState == .ended }

        await repository.startCall(roomID: "!room:example.org")

        #expect(repository.callState == .ready)

        repository.stop()

        service.callEndedContinuation.yield(())

        await Eventually.isTrue(timeout: .milliseconds(200)) { repository.callState == .ended }

        #expect(repository.callState == .ready)
    }

    // MARK: Fixtures

    private static func makeSession(
        roomID     : String                                   = "!room:example.org",
        postMessage: @escaping (CallWidgetMessage) async -> Bool = { _ in true }
    ) -> (session: CallSession, continuation: AsyncStream<CallWidgetMessage>.Continuation) {

        let (stream, continuation) = AsyncStream<CallWidgetMessage>.makeStream(bufferingPolicy: .unbounded)

        let session = CallSession(
            roomID           : roomID,
            widgetURL        : URL(string: "https://call.example.org/widget")!,
            messagesToWebView: stream,
            postMessage      : postMessage
        )

        return (session, continuation)
    }

    /// Records the messages a fake session's `postMessage` closure was called with, from whatever
    /// isolation context that closure runs in.
    private actor Recorder {

        private(set) var messages: [CallWidgetMessage] = []

        func record(_ message: CallWidgetMessage) {
            messages.append(message)
        }
    }
}
