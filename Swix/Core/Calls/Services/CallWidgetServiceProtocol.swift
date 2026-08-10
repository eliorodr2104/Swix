//
//  CallWidgetServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Turns a room id into a ready-to-load Element Call session.
///
/// Builds the widget settings, asks the SDK for the webview URL, and starts the widget driver that
/// carries messages back and forth once a WKWebView is attached to the returned `CallSession`'s
/// message channel. Only one call is prepared at a time: starting a new one replaces whatever was
/// active before.
protocol CallWidgetServiceProtocol {

    /// Fires once whenever the active call's widget driver stops on its own — a dropped connection,
    /// a remote hangup, a widget crash — rather than through `endCall()`.
    var callEndedEvents: AsyncStream<Void> { get }

    /// Whether the given room already has a call in progress that starting here would join.
    func hasActiveCall(inRoom roomID: String) -> Bool

    /// Builds a fresh session for the given room, tearing down any call this service prepared before.
    func prepareCall(
        roomID       : String,
        configuration: CallWidgetConfiguration
    ) async throws -> CallSession

    /// Stops the active call's widget driver, if there is one.
    func endCall() async
}
