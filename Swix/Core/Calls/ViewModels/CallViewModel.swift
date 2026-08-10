//
//  CallViewModel.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Observation

/// Everything a call screen needs to host Element Call in a WKWebView.
///
/// Wiring is meant to take a few lines: load `widgetURL` once it stops being nil, forward every
/// element `messagesForWebView` yields into the webview with something like
/// `webView.evaluateJavaScript("postMessage(\(json), '*')")`, and register a `WKScriptMessageHandler`
/// whose `userContentController(_:didReceive:)` calls `handleMessageFromWebView(_:)` with the
/// message body. Nothing here ever mentions MatrixRustSDK.
@Observable
final class CallViewModel {

    /// The failure to present. Views clear it by setting it back to nil.
    var failure: UserFacingFailure?

    @ObservationIgnored
    private let repository: CallRepository

    init(repository: CallRepository) {
        self.repository = repository
    }

    /// Where the call stands right now.
    var state: CallState {
        repository.callState
    }

    /// The page for the WKWebView to load, or nil until a call has been prepared.
    var widgetURL: URL? {
        repository.activeSession?.widgetURL
    }

    /// Messages the widget driver wants delivered to the webview, as raw widget-api JSON.
    var messagesForWebView: AsyncStream<CallWidgetMessage> {
        repository.activeSession?.messagesToWebView ?? AsyncStream<CallWidgetMessage> {
            $0.finish()
        }
    }

    /// Whether a room already has a call in progress that starting here would join instead.
    func hasActiveCall(inRoom roomID: String) -> Bool {
        repository.hasActiveCall(inRoom: roomID)
    }

    /// Prepares and starts (or joins) a call in the given room.
    func start(inRoom roomID: String) async {
        await repository.startCall(roomID: roomID)

        updateFailure()
    }

    /// Forwards a message the webview's script handler received back to the widget driver.
    func handleMessageFromWebView(_ json: String) async {
        guard let message = CallWidgetMessage(json: json) else {
            return
        }

        await repository.postMessageFromWebView(message)
    }

    /// Ends the call and releases its widget driver.
    func hangUp() async {
        await repository.hangUp()

        updateFailure()
    }

    private func updateFailure() {
        guard let failure = repository.failure else {
            self.failure = nil

            return
        }

        self.failure = UserFacingFailure(
            title      : Self.title(for: failure),
            message    : failure.message,
            isRetryable: failure.isRetryable
        )
    }

    private static func title(for failure: CallFailure) -> String {
        switch failure {
            case .noActiveClient   : "You are not signed in"
            case .roomUnavailable  : "That room could not be found"
            case .widgetSetupFailed: "The call could not be started"
            case .openIdTokenFailed: "The call could not be authorized"
            case .sdk              : "Something went wrong"
        }
    }
}
