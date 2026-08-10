//
//  SDKCallbackEvents.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


// A stream carries exactly one value type, so every SDK callback that is either multi method or
// multi argument is flattened here into a single Sendable payload before it leaves the bridge.

/// Everything the SDK reports through `ClientDelegate`, as one stream of events.
nonisolated enum SDKClientEvent: Sendable {

    /// The access token was rejected by the homeserver. A soft logout keeps the session directory.
    case authError(isSoftLogout: Bool)

    /// A background task the SDK started on our behalf failed.
    case backgroundTaskError(taskName: String, reason: BackgroundTaskFailureReason)
}

/// Every step of an interactive verification, as one stream of events.
nonisolated enum SDKVerificationEvent: Sendable {

    /// Another device asked to verify this session.
    case receivedRequest(details: SessionVerificationRequestDetails)

    /// The other side accepted the request we sent.
    case acceptedRequest

    /// The short authentication string exchange began.
    case startedSas

    /// The emojis or decimals to compare are available.
    case receivedData(data: SessionVerificationData)

    /// The flow ended in an error, typically a mismatch or a network failure.
    case failed

    /// Either side cancelled the flow.
    case cancelled

    /// Both sides confirmed and the devices are now verified.
    case finished
}

/// A send queue update tagged with the room it belongs to.
nonisolated struct SDKSendQueueRoomUpdate: Sendable {

    /// The room whose local echoes changed.
    let roomID: String

    /// What happened to one of the queued events.
    let update: RoomSendQueueUpdate
}

/// A wedged send queue: the SDK has already disabled that room's queue when this arrives.
nonisolated struct SDKSendQueueRoomError: Sendable {

    /// The room whose queue was disabled.
    let roomID: String

    /// The failure that wedged the queue.
    let error: ClientError
}

/// A notification produced by sync, tagged with its room.
nonisolated struct SDKSyncNotification: Sendable {

    /// The resolved notification, already carrying sender and room information. Spelled with its
    /// module because Core declares a `NotificationItem` of its own.
    let notification: MatrixRustSDK.NotificationItem

    /// The room the notifying event was sent to.
    let roomID: String
}

/// A room scoped account data event tagged with its room.
nonisolated struct SDKRoomAccountDataEvent: Sendable {

    /// The decoded account data event.
    let event: RoomAccountDataEvent

    /// The room the event belongs to.
    let roomID: String
}

/// Who is currently typing in a room.
nonisolated struct SDKTypingNotification: Sendable {

    /// The users typing right now, the current user excluded by the SDK.
    let userIDs: [String]
}

/// The only thing `NotificationSettingsDelegate` reports, modelled as a value so it can stream.
nonisolated enum SDKNotificationSettingsEvent: Sendable {

    /// Some push rule changed, every cached notification setting must be reloaded.
    case settingsDidChange
}
