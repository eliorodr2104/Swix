//
//  TimelineProvider.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import os


/// The default `TimelineProviderProtocol`, a cache of `TimelineService` instances.
final class TimelineProvider: TimelineProviderProtocol {

    private let clientService: any ClientServiceProtocol

    private let roomProvider: any RoomProviding

    // Live timelines are keyed by room id, thread timelines by room id and thread root, so a room
    // can have its conversation and several of its threads open at the same time.
    private var timelines: [String: TimelineService] = [:]

    init(
        clientService: any ClientServiceProtocol,
        roomProvider : any RoomProviding
    ) {
        self.clientService = clientService
        self.roomProvider  = roomProvider
    }

    /// Threaded replies are hidden from the main conversation on purpose: the session enables
    /// threads on the client builder, so every reply also has a thread view of its own to live in.
    func liveTimeline(forRoom roomID: String) async throws -> any TimelineServiceProtocol {
        try await timeline(
            roomID: roomID,
            focus : .live(hideThreadedEvents: true),
            key   : Self.makeKey(roomID: roomID)
        )
    }

    func makeThreadTimeline(
        roomID     : String,
        rootEventID: String
    ) async throws -> any TimelineServiceProtocol {

        try await timeline(
            roomID: roomID,
            focus : .thread(rootEventId: rootEventID),
            key   : Self.makeKey(roomID: roomID, rootEventID: rootEventID)
        )
    }

    func markAllRoomsAsRead() async throws {
        guard let client = clientService.sdkClient else {
            throw TimelineFailure.noActiveClient
        }

        do {
            try await client.markAllRoomsAsRead()

        } catch { throw TimelineFailure.actionFailed(SDKErrorInfo(error)) }
    }

    func release(roomID: String) {
        let threadPrefix = Self.makeKey(roomID: roomID) + Self.keySeparator

        for (key, timeline) in timelines where key == roomID || key.hasPrefix(threadPrefix) {
            timeline.shutdown()

            timelines[key] = nil
        }
    }

    func shutdown() {
        timelines.values.forEach { $0.shutdown() }
        timelines.removeAll()
    }

    private static let keySeparator = "|"

    private static func makeKey(
        roomID     : String,
        rootEventID: String? = nil
    ) -> String {

        guard let rootEventID else {
            return roomID
        }

        return roomID + keySeparator + rootEventID
    }

    /// A timeline that failed to start is not kept, so the next attempt builds a fresh one instead
    /// of handing back a service that will never emit anything.
    private func timeline(
        roomID: String,
        focus : TimelineFocus,
        key   : String
    ) async throws -> any TimelineServiceProtocol {

        if let cached = timelines[key] {
            try await cached.start()

            return cached
        }

        let service = TimelineService(
            roomID       : roomID,
            focus        : focus,
            clientService: clientService,
            roomProvider : roomProvider
        )

        timelines[key] = service

        do {
            try await service.start()

        } catch {
            timelines[key] = nil

            throw error
        }

        Log.timeline.notice("Timeline cached for key \(key, privacy: .private)")

        return service
    }
}
