//
//  MockWidgetDriverHandle.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// A `WidgetDriverHandle` with no Rust object behind it, standing in for a running Element Call
/// widget driver in `CallWidgetChannel` tests.
///
/// `WidgetDriverHandleProtocol` is two methods, tiny enough to fake directly per this codebase's
/// mocking rule; both `recv` and `send` are `open`, and `init(noHandle:)` exists, per the class's
/// own doc comment, "for fakes in tests, mostly".
///
/// `nonisolated` because the SDK class it subclasses is: without it the inherited initializers and the
/// two overrides would come out main actor isolated and stop matching what they override.
nonisolated final class MockWidgetDriverHandle: WidgetDriverHandle, @unchecked Sendable {

    private var pendingMessages: [String]

    private let blocksForever: Bool

    private(set) var sentMessages: [String] = []

    var sendReturnValue = true

    /// - Parameters:
    ///   - messagesToDeliver: What `recv()` hands back, one call at a time, before it starts
    ///     returning nil the way a driver that stopped on its own would.
    ///   - blocksForever: When true, `recv()` never resolves once `messagesToDeliver` is drained,
    ///     the way a still-running driver's next message never arrives on its own. It only unblocks
    ///     when the caller's task is cancelled, which is exactly how `CallWidgetChannel.stop()` is
    ///     meant to end the pump.
    init(
        messagesToDeliver: [String] = [],
        blocksForever    : Bool     = false
    ) {
        self.pendingMessages = messagesToDeliver
        self.blocksForever   = blocksForever

        super.init(noHandle: WidgetDriverHandle.NoHandle())
    }

    required init(unsafeFromHandle handle: UInt64) {
        fatalError("MockWidgetDriverHandle is never lifted from a real FFI handle")
    }

    override func recv() async -> String? {
        guard !pendingMessages.isEmpty else {
            if blocksForever {
                try? await Task.sleep(for: .seconds(999))
            }

            return nil
        }

        return pendingMessages.removeFirst()
    }

    override func send(msg: String) async -> Bool {
        sentMessages.append(msg)

        return sendReturnValue
    }
}
