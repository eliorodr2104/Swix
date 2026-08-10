//
//  CallState.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// High level state of an Element Call session, expressed as a small domain enum so the rest of
/// Core never has to import MatrixRustSDK just to read it.
///
/// `failed` stands in for whatever the SDK raised while preparing the call; the repository keeps
/// the actual `CallFailure` in a separate property, the same split `SyncState` uses for its own
/// `.failed` case.
enum CallState: Equatable {

    /// No call has been started.
    case idle

    /// The widget settings, webview URL and driver are being built.
    case preparing

    /// The session is ready: a webview can load `widgetURL`, but nothing has joined yet.
    case ready

    /// The webview has talked back to the driver at least once, so the call is actively connected.
    case ongoing

    /// The call was hung up, either by the user or because its driver stopped on its own.
    case ended

    /// Preparing the call failed. See the repository's `failure` for the reason.
    case failed
}
