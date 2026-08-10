//
//  MockWidgetDriver.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// A `WidgetDriver` with no Rust object behind it, for `CallWidgetChannel` tests.
///
/// `WidgetDriverProtocol` is a single method, tiny enough to fake directly per this codebase's
/// mocking rule; `run` is `open` and `init(noHandle:)` exists, per the class's own doc comment,
/// "for fakes in tests, mostly". `CallWidgetChannel` never awaits this call's completion, so the
/// override just records that it happened and returns.
///
/// `nonisolated` because the SDK class it subclasses is: without it the inherited initializers and the
/// `run` override would come out main actor isolated and stop matching what they override.
nonisolated final class MockWidgetDriver: WidgetDriver, @unchecked Sendable {

    private(set) var runCallCount = 0

    init() {
        super.init(noHandle: WidgetDriver.NoHandle())
    }

    required init(unsafeFromHandle handle: UInt64) {
        fatalError("MockWidgetDriver is never lifted from a real FFI handle")
    }

    override func run(
        room                : Room,
        capabilitiesProvider: WidgetCapabilitiesProvider
    ) async {

        runCallCount += 1
    }
}
