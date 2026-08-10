//
//  VerificationEmojiMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK

/// Turns the short authentication string the SDK negotiated into something a screen can show.
enum VerificationEmojiMapper {

    /// Maps `SessionVerificationData`, returning nil when the two devices settled on decimal SAS.
    ///
    /// Swix always offers the emoji method and has no screen for decimals, so nil is the signal to
    /// abandon the flow rather than a value the caller can fall back on.
    static func makeEmojiPairs(from data: SessionVerificationData) -> [EmojiPair]? {
        switch data {
            case .emojis(let emojis, _): makeEmojiPairs(from: emojis)
            case .decimals             : nil
        }
    }

    /// Maps the SDK emoji objects, calling `description()` explicitly because the generated class
    /// exposes it as a method that would otherwise resolve to `CustomStringConvertible`.
    private static func makeEmojiPairs(
        from emojis: [SessionVerificationEmoji]
    ) -> [EmojiPair] {
    
        emojis.enumerated().map { index, emoji in
            EmojiPair(
                id         : index,
                symbol     : emoji.symbol(),
                description: emoji.description()
            )
        }
    }
}
