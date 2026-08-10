//
//  CallWidgetConfiguration.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// Why the widget is being opened: starting a fresh call or joining one already running.
///
/// The SDK's own `Intent` also distinguishes direct message rooms, which Swix does not need yet;
/// `CallWidgetSettingsMapper` maps both cases onto the plain, non-DM variants.
enum CallIntent: Equatable {

    /// Nobody else is in the room's call yet.
    case startCall

    /// The room already has an active call to join.
    case joinExisting
}

/// Mirrors the SDK's `EncryptionSystem` without depending on it, so the model stays SDK-free.
enum CallEncryptionMode: Equatable {

    /// No per-participant encryption and no shared password.
    case unencrypted

    /// Element Call's own per-participant key exchange, the default for Matrix rooms.
    case perParticipantKeys

    /// A shared password baked into the widget URL.
    case sharedSecret(secret: String)
}

/// Domain configuration for starting or joining an Element Call session in a room.
///
/// Mirrors the fields of the SDK's `VirtualElementCallWidgetProperties` / `VirtualElementCallWidgetConfig`
/// split without depending on MatrixRustSDK; `CallWidgetSettingsMapper` does the actual translation.
struct CallWidgetConfiguration: Equatable {

    /// The Element Call deployment to open, defaulting to `MatrixConfiguration.elementCallBaseUrl`.
    let baseURL: String

    /// Whether this is starting a new call or joining one in progress.
    let intent: CallIntent

    /// How the call's media should be encrypted.
    let encryption: CallEncryptionMode

    /// Whether to skip the pre-join lobby and connect immediately.
    let skipLobby: Bool

    /// Whether Element Call's own branding header should be shown.
    let showHeader: Bool

    /// Whether the widget should join the call as soon as it loads, rather than waiting for it.
    let preload: Bool

    /// Whether the webview should be kept from navigating to Element Call's own calls list.
    let confineToRoom: Bool

    init(
        intent       : CallIntent,
        baseURL      : String             = MatrixConfiguration.elementCallBaseUrl,
        encryption   : CallEncryptionMode = .perParticipantKeys,
        skipLobby    : Bool               = false,
        showHeader   : Bool               = false,
        preload      : Bool               = false,
        confineToRoom: Bool               = true
    ) {
        self.baseURL       = baseURL
        self.intent        = intent
        self.encryption    = encryption
        self.skipLobby     = skipLobby
        self.showHeader    = showHeader
        self.preload       = preload
        self.confineToRoom = confineToRoom
    }
}
