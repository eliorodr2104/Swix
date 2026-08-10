//
//  TestClock.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// A `Clock` whose time only moves when a test calls `advance(by:)`, so debounce and timeout logic
/// can be exercised deterministically instead of waiting on the wall clock.
///
/// Nothing under Core currently accepts an injected `Clock`, but every `Duration` based delay in
/// the app (search debouncing, the sync background grace period) is one default parameter away
/// from taking one, and this is the fake that test would reach for on that day.
final class TestClock: Clock, @unchecked Sendable {

    /// A point in the fake timeline, expressed as an offset from the clock's creation.
    struct Instant: InstantProtocol {

        fileprivate let offset: Duration

        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }

        static func == (lhs: Instant, rhs: Instant) -> Bool { lhs.offset == rhs.offset }

        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }

        func duration(to other: Instant) -> Duration { other.offset - offset }
    }

    private let lock = NSLock()

    private var currentInstant = Instant(offset: .zero)

    private var waiters: [(deadline: Instant, continuation: CheckedContinuation<Void, Never>)] = []

    init() {}

    /// The fake time right now, starting at zero and moving only through `advance(by:)`.
    var now: Instant {
        lock.lock()
        defer { lock.unlock() }

        return currentInstant
    }

    /// Always zero: a fake clock has nothing coarser to offer than exact instants.
    var minimumResolution: Duration { .zero }

    /// Suspends until `deadline`, or returns immediately when it has already passed.
    ///
    /// A sleeper that never gets an `advance(by:)` past its deadline stays suspended forever,
    /// which is deliberate: a test that forgets to advance the clock should hang, not pass by
    /// accident.
    func sleep(
        until deadline : Instant,
        tolerance      : Duration? = nil
    ) async throws {

        await withCheckedContinuation { continuation in
            lock.lock()

            if deadline <= currentInstant {
                lock.unlock()
                continuation.resume()

                return
            }

            waiters.append((deadline, continuation))
            lock.unlock()
        }
    }

    /// Moves fake time forward by `duration`, resuming every sleeper whose deadline is now due.
    func advance(by duration: Duration) {
        lock.lock()
        currentInstant = currentInstant.advanced(by: duration)

        let due = waiters.filter { $0.deadline <= currentInstant }
        waiters.removeAll { $0.deadline <= currentInstant }
        lock.unlock()

        due.forEach { $0.continuation.resume() }
    }
}
