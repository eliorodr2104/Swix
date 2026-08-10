//
//  MockAccountDataService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
@testable import Swix


/// A raw, `Data` based double for `AccountDataServiceProtocol`, which is what lets a test exercise
/// `AccountDataDecoding`'s generic typed helpers without ever touching JSON by hand in the
/// production code: the helpers are protocol extensions, so this mock is all a test needs to run
/// them for real.
final class MockAccountDataService: AccountDataServiceProtocol {

    var globalValuesByType: [String: Data] = [:]

    var roomValuesByType: [String: Data] = [:]

    private(set) var setGlobalCalls: [(eventType: String, json: String)] = []

    private(set) var observedGlobalTypes: [String] = []

    private(set) var observedRoomTypes: [(roomID: String, eventType: String)] = []

    private(set) var shutdownCallCount = 0

    var fetchError: (any Error)?

    var setError: (any Error)?

    var observeGlobalError: (any Error)?

    var observeRoomError: (any Error)?

    /// Continuations for streams already vended by `observeGlobal(eventType:)`, keyed by wire
    /// event type, so a test can push a later raw value through after subscribing.
    private var globalContinuations: [String: AsyncStream<Data>.Continuation] = [:]

    private var roomContinuations: [String: AsyncStream<Data>.Continuation] = [:]

    func global(eventType: AccountDataEventType) async throws -> Data? {
        if let fetchError {
            throw fetchError
        }

        return globalValuesByType[eventType.rawValue]
    }

    func setGlobal(
        eventType: AccountDataEventType,
        content  : some Encodable
    ) async throws {

        if let setError {
            throw setError
        }

        let data = try JSONEncoder().encode(content)

        setGlobalCalls.append((eventType.rawValue, String(data: data, encoding: .utf8) ?? ""))
        globalValuesByType[eventType.rawValue] = data
    }

    func observeGlobal(eventType: AccountDataEventType) throws -> AsyncStream<Data> {
        if let observeGlobalError {
            throw observeGlobalError
        }

        observedGlobalTypes.append(eventType.rawValue)

        let (stream, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .unbounded)

        globalContinuations[eventType.rawValue] = continuation

        if let current = globalValuesByType[eventType.rawValue] {
            continuation.yield(current)
        }

        return stream
    }

    func observeRoom(
        roomID   : String,
        eventType: AccountDataEventType
    ) throws -> AsyncStream<Data> {

        if let observeRoomError {
            throw observeRoomError
        }

        observedRoomTypes.append((roomID, eventType.rawValue))

        let (stream, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .unbounded)

        roomContinuations["\(roomID)/\(eventType.rawValue)"] = continuation

        return stream
    }

    func shutdown() {
        shutdownCallCount += 1
    }

    /// Test-only access to push a later value through a global stream already vended.
    func yieldGlobal(
        _ data   : Data,
        eventType: AccountDataEventType
    ) {

        globalValuesByType[eventType.rawValue] = data
        globalContinuations[eventType.rawValue]?.yield(data)
    }

    /// Test-only access to push a later value through a room stream already vended.
    func yieldRoom(
        _ data   : Data,
        roomID   : String,
        eventType: AccountDataEventType
    ) {

        roomContinuations["\(roomID)/\(eventType.rawValue)"]?.yield(data)
    }
}
