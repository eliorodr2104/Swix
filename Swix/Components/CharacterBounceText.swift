//
//  CharacterBounceText.swift
//  Swix
//
//  Created by Eliomar on 10/08/2026.
//

import SwiftUI


/// The characters of a string bouncing one after another, a wave that starts over once it has
/// crossed the whole string.
///
/// Meant to stand in for a text field's content while that content is being validated, sitting
/// exactly where the still text normally sits. The wave is a pure function of time, the same
/// discipline as every other loop in the app: nothing accumulates, so it can run for as long as
/// the wait lasts and every pass starts on the first character.
struct CharacterBounceText: View {

    /// The text whose characters ride the wave.
    let text: String

    /// Bouncing is movement, so under reduced motion the text stays still and breathes instead.
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// When the wave started, so the first pass begins on the first character rather than wherever
    /// the wall clock happened to be.
    @State
    private var startedAt = Date.now

    var body: some View {

        TimelineView(.animation) { context in

            let elapsed = context.date.timeIntervalSince(startedAt)

            HStack(spacing: 0) {

                ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                    Text(String(character))
                        .offset(y: reduceMotion ? 0 : lift(of: index, at: elapsed))
                }
            }
            .opacity(reduceMotion ? breath(at: elapsed) : 1)
        }
        .lineLimit(1)
        .foregroundStyle(.secondary)
        .accessibilityLabel(text)
    }

    /// The rhythm of the wave for a given text: how long one pass takes to cross it, and how often
    /// a pass starts. Whoever mirrors the wave in another medium, the haptics above all, reads its
    /// timing from here so the two can never drift apart.
    static func waveTiming(
        for text: String
    ) -> (travel: TimeInterval, period: TimeInterval) {

        let travel = charDelay * Double(text.count)

        return (travel, travel + rest)
    }

    /// Vertical displacement of one character: a single half sine hop as the wave passes it, flat
    /// for the rest of the cycle. The rest at the end of each pass is what makes the restart read
    /// as a new wave instead of an endless churn.
    private func lift(
        of index  : Int,
        at elapsed: TimeInterval
    ) -> CGFloat {

        let time  = elapsed.truncatingRemainder(dividingBy: Self.waveTiming(for: text).period)
        let local = time - Self.charDelay * Double(index)

        guard local > 0, local < Self.hopDuration else {
            return 0
        }

        return -Self.hopHeight * sin(.pi * local / Self.hopDuration)
    }

    /// The reduced motion stand in: the whole string gently fading in and out instead of moving.
    private func breath(at elapsed: TimeInterval) -> Double {

        0.65 + 0.2 * sin(2 * .pi * elapsed / 1.6)
    }

    /// Seconds between one character starting its hop and the next one following.
    private static let charDelay: Double = 0.06

    /// Seconds one character spends in the air.
    private static let hopDuration: Double = 0.35

    /// How high a character rises at the top of its hop, in points.
    private static let hopHeight: CGFloat = 5

    /// Seconds of stillness after the wave has crossed the string, before it starts over.
    private static let rest: Double = 0.6
}
