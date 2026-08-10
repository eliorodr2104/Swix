//
//  MockSessionVerificationEmoji.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// A `SessionVerificationEmoji` with no Rust object behind it, standing in for the SDK's own type
/// in `VerificationEmojiMapper` tests.
///
/// The SDK builds this class expressly for fakes like this one: `symbol()` and `description()` are
/// `open`, and `init(noHandle:)` exists, per the class's own doc comment, "for fakes in tests,
/// mostly". Subclassing it here is the tiny UniFFI protocol this codebase mocks directly, as
/// opposed to something like `RoomProtocol`.
///
/// `nonisolated` because the SDK class it subclasses is: without it the initializers and the two
/// accessors would come out main actor isolated and stop matching what they override.
nonisolated final class MockSessionVerificationEmoji: SessionVerificationEmoji, @unchecked Sendable {

    private let stubbedSymbol: String

    private let stubbedDescription: String

    init(
        symbol     : String,
        description: String
    ) {
        self.stubbedSymbol      = symbol
        self.stubbedDescription = description

        super.init(noHandle: SessionVerificationEmoji.NoHandle())
    }

    required init(unsafeFromHandle handle: UInt64) {
        fatalError("MockSessionVerificationEmoji is never lifted from a real FFI handle")
    }

    override func symbol() -> String {
        stubbedSymbol
    }

    override func description() -> String {
        stubbedDescription
    }
}
