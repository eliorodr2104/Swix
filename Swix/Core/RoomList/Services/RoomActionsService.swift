//
//  RoomActionsService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// The default `RoomActionsServiceProtocol`, driving the SDK `Room` directly.
final class RoomActionsService: RoomActionsServiceProtocol {

    private let roomProvider: any RoomProviding

    private let clientService: any ClientServiceProtocol

    init(
        roomProvider : any RoomProviding,
        clientService: any ClientServiceProtocol
    ) {
        self.roomProvider  = roomProvider
        self.clientService = clientService
    }

    func setFavourite(
        _ isFavourite: Bool,
        roomID       : String
    ) async throws {
        let room = try room(roomID)

        try await perform {
            try await room.setIsFavourite(isFavourite: isFavourite, tagOrder: nil)
        }
    }

    func setLowPriority(
        _ isLowPriority: Bool,
        roomID         : String
    ) async throws {
        let room = try room(roomID)

        try await perform {
            try await room.setIsLowPriority(isLowPriority: isLowPriority, tagOrder: nil)
        }
    }

    func markAsRead(roomID: String) async throws {
        let room = try room(roomID)

        try await perform {
            try await room.markAsRead(receiptType: .read)
        }
    }

    func setUnreadFlag(
        _ isUnread: Bool,
        roomID    : String
    ) async throws {
        let room = try room(roomID)

        try await perform {
            try await room.setUnreadFlag(newValue: isUnread)
        }
    }

    func leave(roomID: String) async throws {
        let room = try room(roomID)

        try await perform {
            try await room.leave()
        }
    }

    func trackRecentlyVisited(roomID: String) async throws {
        let client = try activeClient()

        try await perform {
            try await client.trackRecentlyVisitedRoom(room: roomID)
        }
    }

    func recentlyVisitedRoomIDs() async throws -> [String] {
        let client = try activeClient()

        do {
            return try await client.getRecentlyVisitedRooms()
        } catch {
            throw RoomListFailure.actionFailed(SDKErrorInfo(error))
        }
    }

    /// Resolves the SDK room for an id, translating the SDK's own "not found" into the failure a
    /// list action can present.
    private func room(_ roomID: String) throws -> Room {
        do {
            return try roomProvider.room(withId: roomID)
        } catch {
            throw RoomListFailure.roomUnavailable(SDKErrorInfo(error))
        }
    }

    /// Recently visited rooms live on the client's account data rather than on a single room, so
    /// they need the client directly instead of going through `roomProvider`.
    private func activeClient() throws -> Client {
        guard let client = clientService.sdkClient else {
            throw RoomListFailure.noActiveClient
        }

        return client
    }

    /// Normalizes any SDK failure raised by a write into `actionFailed`, the one case every room
    /// action shares regardless of which SDK call underneath it threw.
    private func perform(_ action: () async throws -> Void) async throws {
        do {
            try await action()
        } catch {
            throw RoomListFailure.actionFailed(SDKErrorInfo(error))
        }
    }
}
