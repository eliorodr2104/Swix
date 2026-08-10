//
//  Eventually.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//


/// Polls a condition until it turns true or a timeout elapses, for state a background `Task`
/// updates outside of any `await` a test can hang on directly, such as a repository forwarding an
/// `AsyncStream` into an `@Observable` property.
///
/// `StreamProbe` cannot help here: the stream in question is already being drained by the
/// repository under test, so a second consumer would just race it for elements instead of
/// observing the property the first consumer produces.
enum Eventually {

    /// Repeatedly checks `condition`, sleeping `interval` between attempts, and gives up once
    /// `timeout` has passed. A condition that never turns true simply leaves the assertion after it
    /// failing, rather than hanging the test.
    static func isTrue(
        timeout    : Duration = .seconds(1),
        interval   : Duration = .milliseconds(5),
        _ condition: () -> Bool
    ) async {

        let deadline = ContinuousClock.now + timeout

        while !condition() {
            if ContinuousClock.now >= deadline {
                return
            }

            try? await Task.sleep(for: interval)
        }
    }
}
