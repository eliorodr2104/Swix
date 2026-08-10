//
//  MockSessionVerificationService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

@testable import Swix


/// Records every intent `SessionVerificationRepository` sends and lets a test push
/// `VerificationEvent`s through `eventsContinuation` to drive the state machine from either side
/// of the flow.
final class MockSessionVerificationService: SessionVerificationServiceProtocol {

    let events: AsyncStream<VerificationEvent>

    let eventsContinuation: AsyncStream<VerificationEvent>.Continuation

    private(set) var startCallCount = 0

    private(set) var requestDeviceVerificationCallCount = 0

    private(set) var requestUserVerificationUserIDs: [String] = []

    private(set) var acknowledgeRequestArgs: [(senderID: String, flowID: String)] = []

    private(set) var acceptRequestCallCount = 0

    private(set) var startSasCallCount = 0

    private(set) var approveCallCount = 0

    private(set) var declineCallCount = 0

    private(set) var cancelCallCount = 0

    private(set) var shutdownCallCount = 0

    var startError: (any Error)?

    var requestDeviceVerificationError: (any Error)?

    var requestUserVerificationError: (any Error)?

    var acknowledgeRequestError: (any Error)?

    var acceptRequestError: (any Error)?

    var startSasError: (any Error)?

    var approveError: (any Error)?

    var declineError: (any Error)?

    var cancelError: (any Error)?

    init() {
        (events, eventsContinuation) = AsyncStream<VerificationEvent>.makeStream(bufferingPolicy: .unbounded)
    }

    func start() async throws {
        startCallCount += 1

        if let startError {
            throw startError
        }
    }

    func requestDeviceVerification() async throws {
        requestDeviceVerificationCallCount += 1

        if let requestDeviceVerificationError {
            throw requestDeviceVerificationError
        }
    }

    func requestUserVerification(userID: String) async throws {
        requestUserVerificationUserIDs.append(userID)

        if let requestUserVerificationError {
            throw requestUserVerificationError
        }
    }

    func acknowledgeRequest(
        senderID: String,
        flowID  : String
    ) async throws {

        acknowledgeRequestArgs.append((senderID, flowID))

        if let acknowledgeRequestError {
            throw acknowledgeRequestError
        }
    }

    func acceptRequest() async throws {
        acceptRequestCallCount += 1

        if let acceptRequestError {
            throw acceptRequestError
        }
    }

    func startSas() async throws {
        startSasCallCount += 1

        if let startSasError {
            throw startSasError
        }
    }

    func approve() async throws {
        approveCallCount += 1

        if let approveError {
            throw approveError
        }
    }

    func decline() async throws {
        declineCallCount += 1

        if let declineError {
            throw declineError
        }
    }

    func cancel() async throws {
        cancelCallCount += 1

        if let cancelError {
            throw cancelError
        }
    }

    func shutdown() {
        shutdownCallCount += 1
    }
}
