//
//  LoadingPlaceholderModifier.swift
//  Swix
//
//  Created by Eliomar on 10/08/2026.
//

import SwiftUI


/// Turns a view into a loading placeholder: its content redacted into blocks, with a band of light
/// sweeping across them.
///
/// The redaction is the system's own, so labels and fields collapse into the same rounded shapes the
/// platform uses everywhere. The sweep is masked to those shapes, which is what keeps the light
/// inside the placeholder instead of washing over whatever is behind it.
///
/// A placeholder that comes and goes in a few hundredths of a second reads as a glitch rather than
/// as loading, so it always stays up just long enough to read as intentional, and the real wait is
/// added on top of that.
struct LoadingPlaceholderModifier: ViewModifier {

    /// Whether the work being waited on is still in flight.
    let isActive: Bool

    /// The shortest time the placeholder stays on screen, counted from when it appears. The real
    /// wait is added on top of it, never cut short by it.
    let minimumDuration: Duration

    /// Called once the reveal transition has run its course and the real content is alone on screen
    /// again.
    ///
    /// Waiting out the whole transition is what makes this the right instant to hand focus to a
    /// covered field. While the reveal is still playing, the redacted copy with its duplicate
    /// bindings is in the tree and the real field is not visible yet, so the focus engine resolves
    /// the request against a half transitioned tree, finds nothing eligible and drops it rather than
    /// queueing it.
    let onReveal: (() -> Void)?

    /// Light mode needs a dark band and dark mode a bright one, or the sweep is invisible.
    @Environment(\.colorScheme)
    private var colorScheme

    /// A sweep that slides is a sweep that moves, so it becomes a plain dimming when motion is
    /// unwelcome.
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// What the view actually shows, which lags `isActive` on the way down but never on the way up.
    ///
    /// It starts out true so the very first frame is already a placeholder: showing the real fields
    /// for one frame and redacting them straight after is the flicker this whole type exists to
    /// avoid.
    @State
    private var isShowing = true

    /// When the placeholder appeared. The band's position is measured from here, so every run starts
    /// with the light entering from the left rather than wherever the wall clock happened to be.
    @State
    private var shownAt: Date?

    /// The pending hide, kept so a wait that restarts can call it off.
    @State
    private var hold: Task<Void, Never>?

    func body(content: Content) -> some View {

        // The real content never leaves the tree, it only defocuses and fades while the placeholder
        // covers it. Keeping its identity is what preserves the fields' internal state across the
        // reveal, and blur into opacity is what makes the reveal read as coming into focus.
        content
            .blur(radius: isShowing && !reduceMotion ? Self.contentBlur : 0)
            .opacity(isShowing ? 0 : 1)
            .allowsHitTesting(!isShowing)
            .overlay {
                if isShowing {
                    placeholder(for: content)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .animation(revealAnimation, value: isShowing)
            .onChange(of: isActive, initial: true) { _, isWaiting in
                update(isWaiting: isWaiting)
            }
    }

    /// The stand in that covers the content while it loads: the same view redacted into blocks,
    /// with the band of light running over them.
    private func placeholder(for content: Content) -> some View {

        // Sweep and mask are built from the same redacted content, so the blocks the light travels
        // over are exactly the blocks on screen.
        let redacted = content.redacted(reason: .placeholder)

        return redacted
            .overlay {
                if !reduceMotion, let shownAt {
                    sweep(since: shownAt)
                        .mask { redacted }
                }
            }
            .opacity(reduceMotion ? 0.55 : 1)
            // This is a second copy of the content, focused bindings included. Disabling it keeps
            // the focus engine off it, or focus lands here and dies when the copy fades out.
            .disabled(true)
    }

    /// Calm on the way out, so the fields settle into focus; near instant on the way in, because
    /// going back to shimmering means the content on screen has just stopped being valid.
    private var revealAnimation: Animation {

        isShowing
        ? .smooth(duration: 0.18)
        : .smooth(duration: Self.revealDuration)
    }

    /// The travelling band.
    ///
    /// Its position is a pure function of how long the placeholder has been up, which is what keeps
    /// it from stuttering: a repeating animation restarts every time the layout hands the sweep a
    /// new width, while arithmetic on the clock simply carries on.
    private func sweep(since start: Date) -> some View {

        GeometryReader { proxy in

            TimelineView(.animation) { context in

                let elapsed  = context.date.timeIntervalSince(start)
                let progress = (elapsed / Self.cycle).truncatingRemainder(dividingBy: 1)
                let travel   = 1 + Self.bandWidth

                band
                    .frame(width: proxy.size.width * Self.bandWidth)
                    .offset(
                        x: (progress * travel - Self.bandWidth) * proxy.size.width
                    )
            }
        }
    }

    /// The gradient itself, wider than a thin line so it reads as light rather than a moving edge.
    private var band: some View {

        let highlight = colorScheme == .dark
        ? Color.white.opacity(0.32)
        : Color.black.opacity(0.09)

        return LinearGradient(
            stops: [
                .init(color: .clear,   location: 0.0),
                .init(color: highlight, location: 0.5),
                .init(color: .clear,   location: 1.0)
            ],
            startPoint: .leading,
            endPoint  : .trailing
        )
    }

    /// Shows the placeholder at once when the wait starts, and hides it only once both the wait and
    /// the minimum have run out.
    ///
    /// A nil `shownAt` means the placeholder has not run yet on this appearance, which is how the
    /// screen gets its opening pass of shimmer even when nothing happens to be loading.
    private func update(isWaiting: Bool) {

        hold?.cancel()

        if isWaiting || shownAt == nil {
            shownAt   = .now
            isShowing = true
        }

        guard isWaiting else {
            scheduleHide()

            return
        }
    }

    /// Hides the placeholder after whatever is left of its minimum on screen time, then announces the
    /// reveal once the transition that follows has finished.
    private func scheduleHide() {

        guard isShowing else {
            return
        }

        hold = Task {
            if let remaining = remainingHold, remaining > .zero {
                try? await Task.sleep(for: remaining)
            }

            guard !Task.isCancelled else {
                return
            }

            isShowing = false
            shownAt   = nil

            // Calling back mid transition costs the focus request: the redacted copy is still in the
            // tree and the real field still invisible, so the engine cancels instead of queueing.
            try? await Task.sleep(for: .seconds(Self.revealDuration) + .milliseconds(80))

            guard !Task.isCancelled, !isShowing else {
                return
            }

            onReveal?()
        }
    }

    /// How much of the minimum has not elapsed yet, or nothing when it already has.
    private var remainingHold: Duration? {

        guard let shownAt else {
            return nil
        }

        return minimumDuration - .seconds(Date.now.timeIntervalSince(shownAt))
    }

    /// Seconds the reveal takes to play out. The callback waits on it, so the animation and the wait
    /// can never drift apart.
    private static let revealDuration: Double = 0.45

    /// How defocused the real content sits while covered, in points of blur radius. Small on
    /// purpose: it only has to sell the moment of focus, not hide anything by itself.
    private static let contentBlur: CGFloat = 4

    /// Seconds one pass of the band takes, end to end.
    private static let cycle: Double = 1.2

    /// Width of the band as a fraction of the content it crosses.
    private static let bandWidth: Double = 0.55
}


extension View {

    /// Presents this view as a loading placeholder while `isActive` is true, and as itself the rest
    /// of the time.
    ///
    /// Apply it to the content that should shimmer rather than to the container around it: the sweep
    /// is masked to whatever this modifier wraps, so wrapping a card makes the card itself glow.
    /// `onReveal` fires each time the real content has finished coming back, late on purpose, which
    /// is where focus belongs: handing it over while the reveal still plays makes the focus engine
    /// judge a half transitioned tree and throw the request away.
    func loadingPlaceholder(
        _ isActive     : Bool,
        minimumDuration: Duration = .seconds(0.6),
        onReveal       : (() -> Void)? = nil
    ) -> some View {

        modifier(
            LoadingPlaceholderModifier(
                isActive       : isActive,
                minimumDuration: minimumDuration,
                onReveal       : onReveal
            )
        )
    }
}
