//
//  AccountDataServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Typed access over the SDK's raw JSON string account data API: one account wide value or change
/// stream per event type, plus the room scoped variant the SDK only ever lets you observe.
///
/// Every method here trades in `Data`, not a decoded type. `AccountDataDecoding.swift` layers the
/// generic, typed convenience methods most call sites actually want on top of these four.
protocol AccountDataServiceProtocol {

    /// Fetches the account's current global value for `eventType`, or `nil` when the account has
    /// never set it.
    func global(eventType: AccountDataEventType) async throws -> Data?

    /// Replaces the account's global value for `eventType` with the JSON encoding of `content`.
    func setGlobal(
        eventType: AccountDataEventType,
        content  : some Encodable
    ) async throws

    /// Every later global value for `eventType`, starting with whatever is current at the moment
    /// of subscribing.
    ///
    /// Only the handful of event types the SDK's own closed `AccountDataEventType` enum
    /// enumerates can be observed this way; anything else throws `AccountDataFailure.unobservable`
    /// rather than silently returning a stream that will never emit.
    func observeGlobal(eventType: AccountDataEventType) throws -> AsyncStream<Data>

    /// Every later value `roomID` sets for `eventType`.
    ///
    /// There is no snapshot equivalent: the SDK exposes room scoped account data only as a change
    /// stream, never a getter, so unlike `observeGlobal(eventType:)` the first value only arrives
    /// once something actually changes after subscribing.
    func observeRoom(
        roomID   : String,
        eventType: AccountDataEventType
    ) throws -> AsyncStream<Data>

    /// Releases every subscription this service owns. Called once, when the session ends.
    func shutdown()
}
