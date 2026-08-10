//
//  EmojiPair.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// One entry of the short authentication string the two devices must display identically.
struct EmojiPair: Equatable, Identifiable {

    /// Position in the short authentication string.
    ///
    /// The same emoji can legitimately appear twice in one sequence, so the position is the only
    /// identity a list can use without collapsing two rows into one.
    let id: Int

    /// The emoji itself, the thing the user actually compares.
    let symbol: String

    /// The English name of the emoji, shown underneath so the comparison survives font differences.
    let description: String

    init(
        id         : Int,
        symbol     : String,
        description: String
    ) {
        self.id          = id
        self.symbol      = symbol
        self.description = description
    }
}
