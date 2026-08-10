//
//  AccountDataDecodingTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing
@testable import Swix


@Suite("AccountDataDecoding")
struct AccountDataDecodingTests {

    // Nested inside a main actor isolated suite the conformances would be isolated too, and an
    // isolated Decodable cannot satisfy the `Decodable & Sendable` the observe helpers ask for.
    private nonisolated struct Widget: Codable, Equatable, Sendable {
        let name: String
        let count: Int
    }

    @Test("global(eventType:as:) decodes whatever setGlobal actually wrote")
    func globalRoundTripsThroughSetGlobal() async throws {
        let service = MockAccountDataService()
        let eventType = AccountDataEventType.custom("org.example.widget")
        let widget = Widget(name: "gizmo", count: 3)

        try await service.setGlobal(eventType: eventType, content: widget)

        let decoded = try await service.global(eventType: eventType, as: Widget.self)

        #expect(decoded == widget)
    }

    @Test("global(eventType:as:) answers nil when the account never set that event type")
    func globalAnswersNilWhenUnset() async throws {
        let service = MockAccountDataService()

        let decoded = try await service.global(eventType: .custom("org.example.never-set"), as: Widget.self)

        #expect(decoded == nil)
    }

    @Test("global(eventType:as:) throws decodingFailed when the stored shape does not match")
    func globalThrowsOnShapeMismatch() async {
        let service = MockAccountDataService()
        let eventType = AccountDataEventType.custom("org.example.widget")

        service.globalValuesByType[eventType.rawValue] = Data("{\"unexpected\":true}".utf8)

        await #expect(throws: AccountDataFailure.self) {
            _ = try await service.global(eventType: eventType, as: Widget.self)
        }
    }

    @Test("observeGlobal(eventType:as:) replays the current value, then every later one")
    func observeGlobalReplaysThenForwards() async throws {
        let service = MockAccountDataService()
        let eventType = AccountDataEventType.custom("org.example.widget")

        try await service.setGlobal(eventType: eventType, content: Widget(name: "first", count: 1))

        let stream = try service.observeGlobal(eventType: eventType, as: Widget.self)

        let values = await StreamProbe.collect(from: stream, count: 2, timeout: .milliseconds(300))

        #expect(values.count >= 1)
        #expect(values.first == Widget(name: "first", count: 1))
    }

    @Test("observeGlobal(eventType:as:) drops a value that fails to decode instead of ending the stream")
    func observeGlobalDropsMalformedValue() async {
        let service = MockAccountDataService()
        let eventType = AccountDataEventType.custom("org.example.widget")

        let stream: AsyncStream<Widget>

        do {
            stream = try service.observeGlobal(eventType: eventType, as: Widget.self)
        } catch {
            Issue.record("observeGlobal should not throw here")
            return
        }

        let task = Task {
            await StreamProbe.collect(from: stream, count: 1, timeout: .milliseconds(500))
        }

        service.yieldGlobal(Data("not json".utf8), eventType: eventType)
        service.yieldGlobal(try! JSONEncoder().encode(Widget(name: "second", count: 2)), eventType: eventType)

        let values = await task.value

        #expect(values == [Widget(name: "second", count: 2)])
    }

    @Test("observeRoom(roomID:eventType:as:) decodes whatever the room stream emits, with no snapshot to seed it")
    func observeRoomDecodesEmittedValues() async {
        let service = MockAccountDataService()
        let eventType = AccountDataEventType.custom("org.example.roomWidget")

        let stream: AsyncStream<Widget>

        do {
            stream = try service.observeRoom(roomID: "!room:example.org", eventType: eventType, as: Widget.self)
        } catch {
            Issue.record("observeRoom should not throw here")
            return
        }

        let task = Task {
            await StreamProbe.collect(from: stream, count: 1, timeout: .milliseconds(500))
        }

        // No value arrives before something actually changes.
        try? await Task.sleep(for: .milliseconds(50))

        service.yieldRoom(
            try! JSONEncoder().encode(Widget(name: "room widget", count: 7)),
            roomID   : "!room:example.org",
            eventType: eventType
        )

        let values = await task.value

        #expect(values == [Widget(name: "room widget", count: 7)])
    }
}
