//
//  CallViewModelTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing
@testable import Swix


@Suite("CallViewModel")
struct CallViewModelTests {

    @Test("A fresh view model has no call: idle, no URL, and an already finished message stream")
    func freshViewModelIsIdle() async {
        let (_, viewModel) = Self.makeViewModel()

        #expect(viewModel.state == .idle)
        #expect(viewModel.widgetURL == nil)
        #expect(viewModel.failure == nil)

        let messages = await StreamProbe.collect(from: viewModel.messagesForWebView, count: 1, timeout: .milliseconds(200))
        #expect(messages.isEmpty)
    }

    @Test("hasActiveCall(inRoom:) reads through to the repository")
    func hasActiveCallReadsThrough() {
        let (service, viewModel) = Self.makeViewModel()
        service.hasActiveCallResult = true

        #expect(viewModel.hasActiveCall(inRoom: "!room:example.org"))
    }

    @Test("start(inRoom:) prepares the call and exposes its widget URL once ready")
    func startPreparesTheCall() async {
        let (service, viewModel) = Self.makeViewModel()
        let widgetURL = URL(string: "https://call.example.org/widget")!
        service.prepareCallResult = .success(
            Self.makeSession(widgetURL: widgetURL)
        )

        await viewModel.start(inRoom: "!room:example.org")

        #expect(viewModel.state == .ready)
        #expect(viewModel.widgetURL == widgetURL)
        #expect(viewModel.failure == nil)
    }

    @Test("handleMessageFromWebView forwards a valid message and marks the call ongoing")
    func handleMessageForwardsValidMessages() async {
        let (service, viewModel) = Self.makeViewModel()
        let recorder = Recorder()
        service.prepareCallResult = .success(
            Self.makeSession(postMessage: { message in
                await recorder.record(message)
                return true
            })
        )

        await viewModel.start(inRoom: "!room:example.org")
        await viewModel.handleMessageFromWebView("{\"hello\":1}")

        #expect(viewModel.state == .ongoing)
        #expect(await recorder.messages == [CallWidgetMessage(json: "{\"hello\":1}")])
    }

    @Test("handleMessageFromWebView drops an empty payload without touching the call state")
    func handleMessageDropsEmptyPayload() async {
        let (service, viewModel) = Self.makeViewModel()
        let recorder = Recorder()
        service.prepareCallResult = .success(
            Self.makeSession(postMessage: { message in
                await recorder.record(message)
                return true
            })
        )

        await viewModel.start(inRoom: "!room:example.org")
        await viewModel.handleMessageFromWebView("")

        #expect(viewModel.state == .ready)
        #expect(await recorder.messages.isEmpty)
    }

    @Test("hangUp() ends the call and clears the widget URL")
    func hangUpEndsTheCall() async {
        let (service, viewModel) = Self.makeViewModel()
        service.prepareCallResult = .success(Self.makeSession())

        await viewModel.start(inRoom: "!room:example.org")
        await viewModel.hangUp()

        #expect(viewModel.state == .ended)
        #expect(viewModel.widgetURL == nil)
        #expect(service.endCallCallCount == 1)
    }

    @Test(
        "Every CallFailure case titles the failure banner correctly",
        arguments: [
            (CallFailure.noActiveClient, "You are not signed in"),
            (CallFailure.roomUnavailable(await Fixtures.sdkErrorInfo()), "That room could not be found"),
            (CallFailure.widgetSetupFailed(await Fixtures.sdkErrorInfo()), "The call could not be started"),
            (CallFailure.openIdTokenFailed(await Fixtures.sdkErrorInfo()), "The call could not be authorized"),
            (CallFailure.sdk(await Fixtures.sdkErrorInfo()), "Something went wrong")
        ]
    )
    func titleMapping(
        failure      : CallFailure,
        expectedTitle: String
    ) async {

        let (service, viewModel) = Self.makeViewModel()
        service.prepareCallResult = .failure(failure)

        await viewModel.start(inRoom: "!room:example.org")

        #expect(viewModel.state == .failed)
        #expect(viewModel.failure?.title == expectedTitle)
        #expect(viewModel.failure?.message == failure.message)
        #expect(viewModel.failure?.isRetryable == failure.isRetryable)
    }

    // MARK: Fixtures

    private static func makeViewModel() -> (service: MockCallWidgetService, viewModel: CallViewModel) {
        let service = MockCallWidgetService()
        let repository = CallRepository(widgetService: service)
        let viewModel = CallViewModel(repository: repository)

        return (service, viewModel)
    }

    private static func makeSession(
        widgetURL  : URL                                        = URL(string: "https://call.example.org/widget")!,
        postMessage: @escaping (CallWidgetMessage) async -> Bool = { _ in true }
    ) -> CallSession {

        CallSession(
            roomID           : "!room:example.org",
            widgetURL        : widgetURL,
            messagesToWebView: AsyncStream { $0.finish() },
            postMessage      : postMessage
        )
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
