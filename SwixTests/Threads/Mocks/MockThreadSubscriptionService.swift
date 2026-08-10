//
//  MockThreadSubscriptionService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

@testable import Swix


/// Records every subscription read and write `ThreadListRepository` and `ThreadViewModel` make,
/// with a stubbed answer for the next `loadSubscription` call.
final class MockThreadSubscriptionService: ThreadSubscriptionServiceProtocol {

    private(set) var loadCalls: [(roomID: String, rootEventID: String)] = []

    private(set) var setCalls: [(isSubscribed: Bool, roomID: String, rootEventID: String)] = []

    var stubbedSubscription: ThreadSubscriptionState = .unsubscribed

    var loadError: (any Error)?

    var setError: (any Error)?

    func loadSubscription(
        roomID     : String,
        rootEventID: String
    ) async throws -> ThreadSubscriptionState {

        loadCalls.append((roomID, rootEventID))

        if let loadError {
            throw loadError
        }

        return stubbedSubscription
    }

    func setSubscription(
        _ isSubscribed: Bool,
        roomID        : String,
        rootEventID   : String
    ) async throws {

        setCalls.append((isSubscribed, roomID, rootEventID))

        if let setError {
            throw setError
        }
    }
}
