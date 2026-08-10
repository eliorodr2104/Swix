//
//  LiveLocationRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Observation
import os


/// The single source of truth for one room's live location sharing: who is currently sharing,
/// where they last were, and whether the account itself is one of them.
///
/// `activeShares` is rebuilt exclusively by applying the service's diff batches in order, the same
/// discipline `TimelineRepository` follows for its rows and for the same reason: refetching could
/// reorder or duplicate shares the SDK already placed.
@Observable
final class LiveLocationRepository {

    /// The room this repository watches shares for.
    let roomID: String

    /// Every account currently sharing their location in this room.
    private(set) var activeShares: [LiveLocationShare] = []

    /// Whether the account's own share in this room is currently live.
    private(set) var isSharingOwn = false

    /// The last failure, kept until the next attempt clears it.
    private(set) var failure: LocationFailure?

    @ObservationIgnored
    private let service: any LocationServiceProtocol

    @ObservationIgnored
    private let subscriptions = SubscriptionBag()

    @ObservationIgnored
    private var isObservingOwnBeacon = false

    @ObservationIgnored
    private var isObservingLiveShares = false

    init(
        roomID : String,
        service: any LocationServiceProtocol
    ) {
        self.roomID  = roomID
        self.service = service
    }

    /// Starts observing this room's live shares and the account's own beacon updates. Safe to call
    /// more than once, and safe to call again after a failed attempt: only the half that actually
    /// subscribed is skipped the second time, so a room that was briefly unavailable can recover.
    func start() async {
        observeOwnBeaconIfNeeded()
        await observeLiveSharesIfNeeded()
    }

    /// Sends a one-shot location message to this room.
    func sendStaticLocation(_ payload: LocationPayload) async {
        await run {
            try await service.sendStaticLocation(roomID: roomID, payload: payload)
        }
    }

    /// Starts sharing the account's location in this room for `duration`.
    func startLiveShare(duration: TimeInterval) async {
        await run {
            try await service.startLiveShare(roomID: roomID, duration: duration)
        }
    }

    /// Pushes an updated position for the account's own share already in progress.
    func updateLiveShare(_ payload: LocationPayload) async {
        await run {
            try await service.updateLiveShare(roomID: roomID, payload: payload)
        }
    }

    /// Ends the account's own live share in this room.
    func stopLiveShare() async {
        await run {
            try await service.stopLiveShare(roomID: roomID)
        }
    }

    /// Releases every subscription this repository and its service own for this room. Called
    /// once, by whoever created them, when the room's map screen closes.
    func shutdown() {
        subscriptions.cancelAll()
        service.release(roomID: roomID)

        isObservingOwnBeacon = false
        isObservingLiveShares = false
    }

    /// The client wide own-beacon stream always exists once the service is built, whether or not
    /// this particular room ever gets a live share, so this half is flagged done unconditionally:
    /// only `service.start()` inside it can fail, and that failure is reported through `failure`.
    private func observeOwnBeaconIfNeeded() {
        guard !isObservingOwnBeacon else {
            return
        }

        isObservingOwnBeacon = true

        do {
            try service.start()
        } catch {
            store(LocationFailure.wrapping(error))
        }

        subscriptions.retain(
            Task { [weak self, roomID, updates = service.ownBeaconUpdates] in
                for await update in updates where update.roomID == roomID {
                    self?.isSharingOwn = update.isLive
                }
            }
        )
    }

    /// Unlike the own-beacon stream, getting this room's live shares can itself fail, so the flag
    /// is only raised once the subscription actually exists: a room that was briefly unavailable
    /// gets a fresh attempt on the next `start()` instead of being stuck unobserved forever.
    private func observeLiveSharesIfNeeded() async {
        guard !isObservingLiveShares else {
            return
        }

        do {
            let diffs = try await service.liveShares(forRoom: roomID)

            isObservingLiveShares = true

            subscriptions.retain(
                Task { [weak self] in
                    for await batch in diffs {
                        self?.activeShares.applyDiffs(batch)
                    }
                }
            )

            failure = nil
        } catch {
            store(LocationFailure.wrapping(error))
        }
    }

    private func run(_ action: () async throws -> Void) async {
        do {
            try await action()

            failure = nil
        } catch {
            store(LocationFailure.wrapping(error))
        }
    }

    private func store(_ locationFailure: LocationFailure) {
        Log.location.error("Location failure: \(locationFailure.message, privacy: .public)")

        failure = locationFailure
    }
}
