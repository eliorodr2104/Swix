//
//  AccountDataDecoding.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Generic typed access layered over `AccountDataServiceProtocol`'s raw JSON primitives, so most
/// call sites never have to touch `Data` or `JSONDecoder` themselves.
extension AccountDataServiceProtocol {

    /// Fetches and decodes the account's global value for `eventType` as `T`, or `nil` when the
    /// account has never set that event type.
    func global<T: Decodable>(
        eventType: AccountDataEventType,
        as type  : T.Type
    ) async throws -> T? {

        guard let data = try await global(eventType: eventType) else {
            return nil
        }

        return try Self.decode(data, as: type, eventType: eventType)
    }

    /// Every later value the account sets for `eventType`, decoded as `T`, starting with whatever
    /// is current at the moment of subscribing.
    ///
    /// A payload that fails to decode as `T` is dropped rather than ending the stream: one
    /// malformed update should not take every later one down with it.
    func observeGlobal<T: Decodable & Sendable>(
        eventType: AccountDataEventType,
        as type  : T.Type
    ) throws -> AsyncStream<T> {

        Self.decodedStream(from: try observeGlobal(eventType: eventType), eventType: eventType, as: type)
    }

    /// Every later value `roomID` sets for `eventType`, decoded as `T`. See
    /// `AccountDataServiceProtocol.observeRoom(roomID:eventType:)` for why there is no snapshot
    /// equivalent to seed the stream with.
    func observeRoom<T: Decodable & Sendable>(
        roomID   : String,
        eventType: AccountDataEventType,
        as type  : T.Type
    ) throws -> AsyncStream<T> {

        Self.decodedStream(
            from     : try observeRoom(roomID: roomID, eventType: eventType),
            eventType: eventType,
            as       : type
        )
    }

    private static func decodedStream<T: Decodable & Sendable>(
        from dataStream: AsyncStream<Data>,
        eventType      : AccountDataEventType,
        as type        : T.Type
    ) -> AsyncStream<T> {

        AsyncStream { continuation in
            let task = Task {
                for await data in dataStream {
                    if let value = try? Self.decode(data, as: type, eventType: eventType) {
                        continuation.yield(value)
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func decode<T: Decodable>(
        _ data   : Data,
        as type  : T.Type,
        eventType: AccountDataEventType
    ) throws -> T {

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw AccountDataFailure.decodingFailed(eventType: eventType.rawValue)
        }
    }
}
