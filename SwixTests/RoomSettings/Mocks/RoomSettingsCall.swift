//
//  RoomSettingsCall.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//


/// Names every write `RoomSettingsServiceProtocol` exposes, so a test can point
/// `MockRoomSettingsService.failingCall` at exactly one of them without a bespoke error property
/// per method.
enum RoomSettingsCall: Equatable {

    /// `rename(_:roomID:)`.
    case rename

    /// `setTopic(_:roomID:)`.
    case setTopic

    /// `setAvatar(data:mimeType:roomID:)`.
    case setAvatar

    /// `removeAvatar(roomID:)`.
    case removeAvatar

    /// `updateJoinRule(_:roomID:)`.
    case updateJoinRule

    /// `updateHistoryVisibility(_:roomID:)`.
    case updateHistoryVisibility

    /// `updateRoomVisibility(_:roomID:)`.
    case updateRoomVisibility

    /// `updateCanonicalAlias(_:roomID:)`.
    case updateCanonicalAlias

    /// `enableEncryption(roomID:)`.
    case enableEncryption

    /// `setOwnMemberDisplayName(_:roomID:)`.
    case setOwnMemberDisplayName
}
