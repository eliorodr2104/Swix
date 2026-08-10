//
//  StreamProbe.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//


/// Collects values off an `AsyncStream` up to a count or a timeout, whichever comes first.
///
/// Every bridge listener and every repository in Core hands back an `AsyncStream` that never
/// finishes on its own, so a plain `for await` in a test would hang the moment fewer values than
/// expected show up. Racing the collection against a timeout is what makes that failure mode a
/// normal, readable assertion instead of a stuck test run.
enum StreamProbe {

    /// Collects up to `count` values from `stream`, giving up after `timeout`.
    ///
    /// The values gathered before either the count or the timeout was reached are always
    /// returned, so a caller that only got 2 of the 3 it asked for still sees those 2 rather than
    /// nothing.
    static func collect<Value: Sendable>(
        from stream: AsyncStream<Value>,
        count      : Int,
        timeout    : Duration = .seconds(1)
    ) async -> [Value] {

        let collector = Collector<Value>(target: count)

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await value in stream {
                    if await collector.append(value) {
                        break
                    }
                }
            }

            group.addTask {
                try? await Task.sleep(for: timeout)
            }

            await group.next()
            group.cancelAll()
        }

        return await collector.values
    }

    /// Holds whatever the racing collection task gathered, so the timeout branch can still read
    /// it after cancelling its sibling.
    private actor Collector<Value: Sendable> {

        private(set) var values: [Value] = []

        private let target: Int

        init(target: Int) {
            self.target = target
        }

        /// Records one value and reports whether the target count has now been reached.
        func append(_ value: Value) -> Bool {
            values.append(value)

            return values.count >= target
        }
    }
}
