//
//  MockRoomActionsService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

@testable import Swix


/// A `RoomActionsServiceProtocol` double that records every call it received and throws
/// `errorToThrow` from all of them once it is set, so a single switch turns every action into a
/// failure the caller has to handle.
final class MockRoomActionsService: RoomActionsServiceProtocol {

    /// Every `(isFavourite, roomID)` pair `setFavourite` was called with, oldest first.
    private(set) var favouriteCalls: [(isFavourite: Bool, roomID: String)] = []

    /// Every `(isLowPriority, roomID)` pair `setLowPriority` was called with, oldest first.
    private(set) var lowPriorityCalls: [(isLowPriority: Bool, roomID: String)] = []

    /// Every room id `markAsRead` was called with, oldest first.
    private(set) var markAsReadCalls: [String] = []

    /// Every `(isUnread, roomID)` pair `setUnreadFlag` was called with, oldest first.
    private(set) var unreadFlagCalls: [(isUnread: Bool, roomID: String)] = []

    /// Every room id `leave` was called with, oldest first.
    private(set) var leaveCalls: [String] = []

    /// Every room id `trackRecentlyVisited` was called with, oldest first.
    private(set) var trackVisitedCalls: [String] = []

    /// What `recentlyVisitedRoomIDs()` returns on success.
    var recentlyVisited: [String] = []

    /// What every call throws once set, nil for a plain success.
    var errorToThrow: (any Error)?

    func setFavourite(
        _ isFavourite: Bool,
        roomID       : String
    ) async throws {

        favouriteCalls.append((isFavourite, roomID))

        if let errorToThrow {
            throw errorToThrow
        }
    }

    func setLowPriority(
        _ isLowPriority: Bool,
        roomID         : String
    ) async throws {

        lowPriorityCalls.append((isLowPriority, roomID))

        if let errorToThrow {
            throw errorToThrow
        }
    }

    func markAsRead(roomID: String) async throws {
        markAsReadCalls.append(roomID)

        if let errorToThrow {
            throw errorToThrow
        }
    }

    func setUnreadFlag(
        _ isUnread: Bool,
        roomID    : String
    ) async throws {

        unreadFlagCalls.append((isUnread, roomID))

        if let errorToThrow {
            throw errorToThrow
        }
    }

    func leave(roomID: String) async throws {
        leaveCalls.append(roomID)

        if let errorToThrow {
            throw errorToThrow
        }
    }

    func trackRecentlyVisited(roomID: String) async throws {
        trackVisitedCalls.append(roomID)

        if let errorToThrow {
            throw errorToThrow
        }
    }

    func recentlyVisitedRoomIDs() async throws -> [String] {
        if let errorToThrow {
            throw errorToThrow
        }

        return recentlyVisited
    }
}
