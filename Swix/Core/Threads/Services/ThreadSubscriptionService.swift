//
//  ThreadSubscriptionService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// The default `ThreadSubscriptionServiceProtocol`, built on `Room.fetchThreadSubscription` and
/// `Room.setThreadSubscription`.
///
/// Nothing is cached here. A subscription is one boolean the homeserver owns and can change on its
/// own, after a mention for instance, so the rows that care about it keep the last answer themselves
/// and ask again whenever they want a fresh one.
final class ThreadSubscriptionService: ThreadSubscriptionServiceProtocol {

    private let roomProvider: any RoomProviding

    init(roomProvider: any RoomProviding) {
        self.roomProvider = roomProvider
    }

    func loadSubscription(
        roomID     : String,
        rootEventID: String
    ) async throws -> ThreadSubscriptionState {

        let room = try activeRoom(withID: roomID)

        do {
            let subscription = try await room.fetchThreadSubscription(threadRootEventId: rootEventID)

            return ThreadSubscriptionMapper.makeState(from: subscription)

        } catch { throw ThreadsFailure.subscriptionFailed(SDKErrorInfo(error)) }
    }

    func setSubscription(
        _ isSubscribed: Bool,
        roomID        : String,
        rootEventID   : String
    ) async throws {

        let room = try activeRoom(withID: roomID)

        do {
            try await room.setThreadSubscription(
                threadRootEventId: rootEventID,
                subscribed       : isSubscribed
            )

        } catch { throw ThreadsFailure.subscriptionFailed(SDKErrorInfo(error)) }
    }

    /// `RoomProviding` fails with our own `SyncFailure` only when sync never ran, which is worth
    /// telling apart from a room the list genuinely does not have.
    private func activeRoom(withID roomID: String) throws -> Room {
        do {
            return try roomProvider.room(withId: roomID)

        } catch is SyncFailure {
            throw ThreadsFailure.notStarted

        } catch { throw ThreadsFailure.roomUnavailable(SDKErrorInfo(error)) }
    }
}
