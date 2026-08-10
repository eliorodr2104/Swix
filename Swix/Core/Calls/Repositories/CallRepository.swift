//
//  CallRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation
import os

/// The single source of truth for the app's one active Element Call session, and the only writer
/// of `CallState`.
///
/// Only one call can be prepared at a time, matching `CallWidgetService`: starting a call while
/// another is active or ending replaces it rather than running two side by side.
@Observable
final class CallRepository {

    /// Where the call stands right now. Views observe this through `CallViewModel`.
    private(set) var callState: CallState = .idle

    /// The prepared session a WKWebView can bind to, or nil while no call is active.
    private(set) var activeSession: CallSession?

    /// The last failure `startCall` raised, kept until the next attempt clears it.
    private(set) var failure: CallFailure?

    @ObservationIgnored
    private let widgetService: any CallWidgetServiceProtocol

    @ObservationIgnored
    private let subscriptions = SubscriptionBag()

    @ObservationIgnored
    private var isObserving = false

    init(widgetService: any CallWidgetServiceProtocol) {
        self.widgetService = widgetService
    }

    /// Whether the given room already has a call in progress that starting here would join.
    func hasActiveCall(inRoom roomID: String) -> Bool {
        widgetService.hasActiveCall(inRoom: roomID)
    }

    /// Prepares and starts a call in the given room, joining one already in progress instead of
    /// starting a second. A no-op while a call is already being prepared or is live.
    func startCall(
        roomID       : String,
        configuration: CallWidgetConfiguration? = nil
    ) async {
    
        observeCallEndedIfNeeded()

        guard callState != .preparing,
              callState != .ready,
              callState != .ongoing else { return }

        callState = .preparing
        failure   = nil

        let intent: CallIntent = hasActiveCall(
            inRoom: roomID
        ) ? .joinExisting : .startCall
        
        let resolvedConfiguration = configuration ?? CallWidgetConfiguration(intent: intent)

        do {
            let session = try await widgetService.prepareCall(
                roomID       : roomID,
                configuration: resolvedConfiguration
            )

            activeSession = session
            callState     = .ready
        } catch {
            Log.calls.error("Could not prepare call: \(String(reflecting: error), privacy: .public)")

            failure   = error as? CallFailure ?? .sdk(SDKErrorInfo(error))
            callState = .failed
        }
    }

    /// Forwards a message the webview posted back to the widget driver, and marks the call as
    /// actively ongoing the first time the widget talks back.
    @discardableResult
    func postMessageFromWebView(_ message: CallWidgetMessage) async -> Bool {
        guard let activeSession else {
            return false
        }

        if callState == .ready {
            callState = .ongoing
        }

        return await activeSession.postMessage(message)
    }

    /// Ends the active call and releases its widget driver.
    func hangUp() async {
        await widgetService.endCall()

        activeSession = nil
        callState     = .ended
    }

    /// Releases every subscription this repository owns. Called once, when the session ends.
    func stop() {
        subscriptions.cancelAll()
    }

    private func observeCallEndedIfNeeded() {
        guard !isObserving else {
            return
        }

        isObserving = true

        subscriptions.retain(
            Task { [weak self, events = widgetService.callEndedEvents] in
                for await _ in events {
                    // AsyncStream hands out buffered elements even to a cancelled consumer, so
                    // stop() alone cannot guarantee this loop never fires afterwards.
                    guard !Task.isCancelled else { break }

                    self?.handleCallEndedRemotely()
                }
            }
        )
    }

    private func handleCallEndedRemotely() {
        activeSession = nil
        callState     = .ended
    }
}
