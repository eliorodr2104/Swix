//
//  HapticsPlayer.swift
//  Swix
//
//  Created by Eliomar on 10/08/2026.
//

import CoreHaptics
import UIKit


/// The app's haptic vocabulary: a rolling wave for waits that show one, and the system's own
/// success and error taps for how they end.
///
/// The wave is a continuous swell whose intensity rises and falls once per pass, looped by the
/// engine itself so it costs nothing per cycle. Everything degrades to silence on hardware without
/// haptics, the simulator included.
final class HapticsPlayer {

    private var engine: CHHapticEngine?

    private var wavePlayer: (any CHHapticAdvancedPatternPlayer)?

    private let notifier = UINotificationFeedbackGenerator()

    /// Starts the rolling swell: `travel` is how long one pass lasts, `period` how often a pass
    /// starts, and the silence between the two is the same rest the visual wave takes.
    func startWave(
        travel: TimeInterval,
        period: TimeInterval
    ) {

        stopWave()
        notifier.prepare()

        guard let engine = readyEngine() else {
            return
        }

        do {
            let player = try engine.makeAdvancedPlayer(
                with: Self.makeWavePattern(travel: travel)
            )

            player.loopEnabled = true
            player.loopEnd     = max(period, travel)

            try player.start(atTime: CHHapticTimeImmediate)

            wavePlayer = player
        } catch {
            wavePlayer = nil
        }
    }

    /// Silences the wave. Safe to call when nothing is playing.
    func stopWave() {

        try? wavePlayer?.stop(atTime: CHHapticTimeImmediate)
        wavePlayer = nil
    }

    /// The system's success tap, the one every sheet and payment in iOS ends on.
    func success() {

        notifier.notificationOccurred(.success)
    }

    /// The system's error buzz.
    func error() {

        notifier.notificationOccurred(.error)
    }

    /// Hands back a running engine, creating or reviving one as needed.
    ///
    /// The engine dies whenever the app resigns or the audio session resets, and reviving it here
    /// on demand is what spares the class from cross thread reset handlers.
    private func readyEngine() -> CHHapticEngine? {

        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            return nil
        }

        if let engine, (try? engine.start()) != nil {
            return engine
        }

        guard let fresh = try? CHHapticEngine(), (try? fresh.start()) != nil else {
            engine = nil

            return nil
        }

        engine = fresh

        return fresh
    }

    /// One pass of the swell: a soft continuous rumble whose intensity climbs to its crest halfway
    /// through the travel and dies down again, mirroring the wave crossing the text.
    private static func makeWavePattern(travel: TimeInterval) throws -> CHHapticPattern {

        // A very short text would make a swell too brief to feel, so the pass never goes under a
        // third of a second even when the animation's does.
        let span = max(travel, 0.3)

        let swell = CHHapticEvent(
            eventType   : .hapticContinuous,
            parameters  : [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)
            ],
            relativeTime: 0,
            duration    : span
        )

        let crest = CHHapticParameterCurve(
            parameterID  : .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: 0,          value: 0.10),
                CHHapticParameterCurve.ControlPoint(relativeTime: span * 0.5, value: 0.80),
                CHHapticParameterCurve.ControlPoint(relativeTime: span,       value: 0.05)
            ],
            relativeTime : 0
        )

        return try CHHapticPattern(
            events         : [swell],
            parameterCurves: [crest]
        )
    }
}
