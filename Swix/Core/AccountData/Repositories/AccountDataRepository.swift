//
//  AccountDataRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation
import Foundation
import os


/// The single source of truth for the account's global account data, and the only writer of the
/// cache a settings screen reads.
///
/// Values are cached as raw JSON, keyed by wire event type, rather than as already decoded types:
/// two unrelated screens can cache the same event type through the same repository without either
/// one dictating what the other decodes it as.
@Observable
final class AccountDataRepository {

    /// Every value fetched or observed so far, raw JSON keyed by wire event type. A missing key
    /// means the account never set that event type, or nobody asked for it yet.
    private(set) var values: [String: Data] = [:]

    /// The last failure, kept until the next successful request clears it.
    private(set) var failure: AccountDataFailure?

    @ObservationIgnored
    private let service: any AccountDataServiceProtocol

    @ObservationIgnored
    private let subscriptions = SubscriptionBag()

    @ObservationIgnored
    private var observedEventTypes: Set<String> = []

    init(service: any AccountDataServiceProtocol) {
        self.service = service
    }

    /// The cached value for `eventType`, decoded as `T`, or `nil` if it was never cached or fails
    /// to decode as that type.
    func value<T: Decodable>(
        for eventType: AccountDataEventType,
        as type      : T.Type
    ) -> T? {

        guard let data = values[eventType.rawValue] else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: data)
    }

    /// Fetches `eventType` once and caches the result, without subscribing to later changes.
    func refresh(eventType: AccountDataEventType) async {
        do {
            values[eventType.rawValue] = try await service.global(eventType: eventType)
            failure = nil
        } catch {
            record(error)
        }
    }

    /// Replaces `eventType`'s value on the homeserver and updates the cache immediately, rather
    /// than waiting for the change to round trip back through `observe(eventType:)`.
    func set(
        eventType: AccountDataEventType,
        content  : some Encodable
    ) async {

        do {
            try await service.setGlobal(eventType: eventType, content: content)

            values[eventType.rawValue] = try? JSONEncoder().encode(content)
            failure = nil
        } catch {
            record(error)
        }
    }

    /// Starts keeping `eventType` up to date in the cache as the account, or another of its
    /// devices, changes it. Safe to call more than once for the same event type.
    func observe(eventType: AccountDataEventType) {
        guard !observedEventTypes.contains(eventType.rawValue) else {
            return
        }

        observedEventTypes.insert(eventType.rawValue)

        do {
            let stream = try service.observeGlobal(eventType: eventType)

            subscriptions.retain(Task { [weak self] in
                for await data in stream {
                    self?.values[eventType.rawValue] = data
                }
            })
        } catch {
            record(error)
        }
    }

    /// Releases every subscription this repository and its service own. Called once, when the
    /// session ends.
    func shutdown() {
        subscriptions.cancelAll()
        observedEventTypes.removeAll()
        service.shutdown()
    }

    private func record(_ error: any Error) {
        let accountDataFailure = error as? AccountDataFailure ?? .fetchFailed(SDKErrorInfo(error))

        Log.accountData.error("Account data request failed: \(String(reflecting: error), privacy: .public)")

        failure = accountDataFailure
    }
}
