//
//  VerificationEmojiMapperTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import MatrixRustSDK
import Testing
@testable import Swix


@Suite("VerificationEmojiMapper")
struct VerificationEmojiMapperTests {

    @Test("Maps an emoji SAS payload, preserving order and each emoji's readable name")
    func mapsEmojisPreservingOrder() {
        let emojis: [SessionVerificationEmoji] = [
            MockSessionVerificationEmoji(symbol: "🐱", description: "Cat"),
            MockSessionVerificationEmoji(symbol: "🐶", description: "Dog"),
            MockSessionVerificationEmoji(symbol: "🐱", description: "Cat")
        ]

        let data = SessionVerificationData.emojis(emojis: emojis, indices: Data())

        let pairs = VerificationEmojiMapper.makeEmojiPairs(from: data)

        #expect(pairs == [
            EmojiPair(id: 0, symbol: "🐱", description: "Cat"),
            EmojiPair(id: 1, symbol: "🐶", description: "Dog"),
            EmojiPair(id: 2, symbol: "🐱", description: "Cat")
        ])
    }

    @Test("An empty emoji payload maps to an empty, non-nil array")
    func mapsEmptyEmojiPayload() {
        let data = SessionVerificationData.emojis(emojis: [], indices: Data())

        #expect(VerificationEmojiMapper.makeEmojiPairs(from: data) == [])
    }

    @Test("Decimal SAS has no screen to show, so it maps to nil")
    func decimalsMapToNil() {
        let data = SessionVerificationData.decimals(values: [12, 34, 56])

        #expect(VerificationEmojiMapper.makeEmojiPairs(from: data) == nil)
    }
}
