//
//  AccountDataEventType.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// SDK-free identifier for one kind of account data event, whether it is scoped to the whole
/// account or to a single room.
///
/// The SDK actually has two different closed enums for this (`MatrixRustSDK.AccountDataEventType`
/// for global events, `RoomAccountDataEventType` for room scoped ones) and neither can carry an
/// arbitrary string. This wrapper stores the wire event type directly instead, which is exactly
/// what `Client.accountData(eventType:)` and `setAccountData(eventType:content:)` take, and lets
/// `AccountDataService` decide privately whether a given value also has a matching SDK enum case
/// to observe.
struct AccountDataEventType: Equatable, Hashable {

    /// The wire event type, e.g. `"m.direct"`, or a custom namespaced string none of the cases
    /// below name.
    let rawValue: String

    /// `m.direct`, the map of users to their DM rooms.
    static let direct = AccountDataEventType(rawValue: "m.direct")

    /// `m.identity_server`, the configured identity server base URL.
    static let identityServer = AccountDataEventType(rawValue: "m.identity_server")

    /// `m.ignored_user_list`, mirrored more conveniently by `IgnoredUsersServiceProtocol`.
    static let ignoredUserList = AccountDataEventType(rawValue: "m.ignored_user_list")

    /// `m.push_rules`, the account's push rule set.
    static let pushRules = AccountDataEventType(rawValue: "m.push_rules")

    /// `m.secret_storage.default_key`, which secret storage key recovery should use.
    static let secretStorageDefaultKey = AccountDataEventType(rawValue: "m.secret_storage.default_key")

    /// `m.fully_read`, the room scoped read marker position.
    static let fullyRead = AccountDataEventType(rawValue: "m.fully_read")

    /// `m.tag`, the room scoped set of tags (favourite, low priority, custom ones).
    static let tag = AccountDataEventType(rawValue: "m.tag")

    /// `m.marked_unread`, the room scoped manual unread flag.
    static let markedUnread = AccountDataEventType(rawValue: "m.marked_unread")

    /// `m.secret_storage.key.*`, one specific secret storage key definition.
    static func secretStorageKey(_ keyID: String) -> AccountDataEventType {
        AccountDataEventType(rawValue: "m.secret_storage.key.\(keyID)")
    }

    /// Any event type this wrapper does not already name a case for, such as a client specific
    /// namespace. Fetching and setting a custom type works exactly the same as a named one; only
    /// observing it does not, since the SDK's own enum has no case for it.
    static func custom(_ rawValue: String) -> AccountDataEventType {
        AccountDataEventType(rawValue: rawValue)
    }
}
