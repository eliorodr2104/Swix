//
//  LocationServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Everything a room can do with location: a one-shot share of where the sender is right now, and
/// starting, stopping and watching the live shares that keep updating until they expire.
///
/// This sits in front of two different SDK surfaces without hiding which is which. A one-shot
/// share rides the room's own timeline, so it goes out through whichever `TimelineServiceProtocol`
/// is already open for that room instead of a second timeline this type would have to keep in
/// sync with the first. Live sharing has no timeline equivalent and talks to the SDK's `Room`
/// directly.
protocol LocationServiceProtocol {

    /// Every later change to the account's own live shares, across every room, starting with the
    /// one that was current when `start()` ran. A screen filters this to the room it cares about.
    var ownBeaconUpdates: AsyncStream<OwnBeaconShareUpdate> { get }

    /// Attaches the client wide own-beacon listener. Safe to call more than once.
    func start() throws

    /// Sends a one-shot location message to a room: the sender's position at the moment of
    /// sending, not a live share.
    func sendStaticLocation(
        roomID : String,
        payload: LocationPayload
    ) async throws

    /// Starts sharing the account's location in a room for `duration`, returning the beacon_info
    /// event id backing the new share.
    @discardableResult
    func startLiveShare(
        roomID  : String,
        duration: TimeInterval
    ) async throws -> String

    /// Pushes an updated position for a live share already in progress in a room.
    func updateLiveShare(
        roomID : String,
        payload: LocationPayload
    ) async throws

    /// Ends the account's own live share in a room, before its deadline would have.
    func stopLiveShare(roomID: String) async throws

    /// Every later change to a room's active live shares, starting with the current snapshot.
    ///
    /// Building the observer talks to the homeserver, so this can fail; once it succeeds the
    /// returned stream itself never throws again, it only stops emitting once `release(roomID:)`
    /// is called for that room. Calling this again for a room already being watched hands back the
    /// same stream instead of registering a second listener on the homeserver.
    func liveShares(forRoom roomID: String) async throws -> AsyncStream<[CollectionDiff<LiveLocationShare>]>

    /// The vector tile style the homeserver recommends for rendering shares on a map, nil when it
    /// does not advertise one (MSC3488).
    func tileServer() async -> TileServerInfo?

    /// Releases one room's live share observer, for when its screen closes.
    func release(roomID: String)

    /// Releases every listener this service owns. Called once, when the session ends.
    func shutdown()
}
