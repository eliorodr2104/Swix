//
//  FederationPulseView.swift
//  Swix
//
//  Created by Eliomar on 10/08/2026.
//

import SwiftUI


/// Decorative constellation of homeservers passing messages around, shown while onboarding
/// explains what Matrix actually is.
///
/// There is deliberately no hub in the middle: the user's server is one of five, and some hops
/// never touch it at all. Every visual is a pure function of where the clock sits inside an eight
/// second window, so the loop closes on itself perfectly and nothing has to be remembered between
/// frames.
struct FederationPulseView: View {

    /// Dark mode needs a quieter fill for the secondary servers, the accent is bright enough that
    /// the light mode opacity reads as painted on rather than lit.
    @Environment(\.colorScheme) private var colorScheme

    /// When motion is unwelcome the same composition is drawn at rest, arcs included, so the view
    /// still says "servers talking to each other" without anything moving.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {

        GeometryReader { proxy in

            if reduceMotion {
                constellation(
                    in      : proxy.size,
                    at      : 0,
                    animated: false
                )
            } else {
                TimelineView(.animation) { context in
                    constellation(
                        in      : proxy.size,
                        at      : FederationChoreography.time(of: context.date),
                        animated: true
                    )
                }
            }
        }
        .frame(height: FederationChoreography.height)
        .accessibilityHidden(true)
    }

    /// The whole picture for one instant: traffic painted underneath, servers floating on top.
    ///
    /// Passing `animated` as `false` freezes the servers on their resting positions and turns the
    /// travelling pulses off, which is exactly the reduced motion rendering.
    private func constellation(
        in size : CGSize,
        at time : Double,
        animated: Bool
    ) -> some View {

        ZStack {

            Canvas { context, canvasSize in
                paintBackdrop(
                    into    : &context,
                    size    : canvasSize,
                    time    : time,
                    animated: animated
                )
            }
            .mask {
                // The glows are larger than the view, and a canvas clips whatever leaves it. A
                // blurred, inset rectangle melts all four edges instead of cutting them.
                Rectangle()
                    .padding(30)
                    .blur(radius: 34)
            }

            Canvas { context, canvasSize in
                paintTraffic(
                    into    : &context,
                    size    : canvasSize,
                    time    : time,
                    animated: animated
                )
            }

            ForEach(FederationChoreography.nodes.indices, id: \.self) { index in

                let node = FederationChoreography.nodes[index]

                server(at: index)
                    .frame(
                        width : node.side,
                        height: node.side
                    )
                    .scaleEffect(
                        animated
                        ? FederationChoreography.liveliness(
                            of: index,
                            at: time
                        )
                        : 1
                    )
                    .position(
                        FederationChoreography.position(
                            of      : node,
                            in      : size,
                            at      : time,
                            floating: animated
                        )
                    )
            }
        }
    }

    /// Picks the right body for a server: index zero is the user's, everything else is an abstract
    /// box we know nothing about.
    private func server(at index: Int) -> some View {

        Group {
            if index == FederationChoreography.userIndex {
                userServer
            } else {
                remoteServer(side: FederationChoreography.nodes[index].side)
            }
        }
    }

    /// The user's homeserver. As empty as the others on purpose, the gradient alone marks it as
    /// ours: out here a server is a server, whoever it belongs to.
    private var userServer: some View {

        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors    : [FederationChoreography.logoLight, FederationChoreography.logoDeep],
                    startPoint: FederationChoreography.logoStart,
                    endPoint  : FederationChoreography.logoEnd
                )
            )
            .shadow(
                color : FederationChoreography.accent.opacity(0.45),
                radius: 12,
                y     : 5
            )
    }

    /// Someone else's homeserver: a tinted box with a hairline edge, empty because from here that
    /// is genuinely all we know about it.
    private func remoteServer(side: CGFloat) -> some View {

        let radius = side * 0.3

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(FederationChoreography.accent.opacity(colorScheme == .dark ? 0.16 : 0.22))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(FederationChoreography.accent.opacity(0.35), lineWidth: 1)
            }
    }

    /// Washes the space behind the constellation with a few large accent glows, so the animation
    /// sits in its own pool of colour instead of floating on bare background.
    ///
    /// Each glow is a radial gradient that fades to nothing well before the edges, and they drift
    /// even more slowly than the servers do: weather, not traffic.
    private func paintBackdrop(
        into context: inout GraphicsContext,
        size        : CGSize,
        time        : Double,
        animated    : Bool
    ) {

        for glow in FederationChoreography.glows {

            let center = FederationChoreography.glowCenter(
                of      : glow,
                in      : size,
                at      : time,
                floating: animated
            )

            let radius = glow.radius * min(size.width, size.height)

            // Dark mode glows brighter than it paints: the same opacity that reads as a soft wash
            // on white turns into a spotlight on black, so it gets dimmed there.
            let peak = glow.opacity * (colorScheme == .dark ? 0.72 : 1)

            context.fill(
                dot(
                    at      : center,
                    diameter: radius * 2
                ),
                with: .radialGradient(
                    Gradient(
                        colors: [
                            FederationChoreography.accent.opacity(peak),
                            FederationChoreography.accent.opacity(0)
                        ]
                    ),
                    center     : center,
                    startRadius: 0,
                    endRadius  : radius
                )
            )
        }
    }

    /// Strokes the arc of every hop and, for the ones in flight, the pulse crawling along it.
    ///
    /// Frozen renderings keep the arcs and drop the pulses, which leaves a faint map of who talks
    /// to whom over the course of a loop.
    private func paintTraffic(
        into context: inout GraphicsContext,
        size        : CGSize,
        time        : Double,
        animated    : Bool
    ) {

        for hop in FederationChoreography.hops {

            let origin = FederationChoreography.position(
                of      : FederationChoreography.nodes[hop.from],
                in      : size,
                at      : time,
                floating: animated
            )

            let target = FederationChoreography.position(
                of      : FederationChoreography.nodes[hop.to],
                in      : size,
                at      : time,
                floating: animated
            )

            let control = FederationChoreography.control(
                from: origin,
                to  : target,
                in  : size
            )

            // Servers are translucent, so an arc drawn all the way to the centres would show
            // through them. Start and finish on the rims instead, where a wire would be plugged.
            let launch = FederationChoreography.rim(
                of      : origin,
                facing  : control,
                clearing: FederationChoreography.nodes[hop.from].side
            )

            let landing = FederationChoreography.rim(
                of      : target,
                facing  : control,
                clearing: FederationChoreography.nodes[hop.to].side
            )

            var arc = Path()
            arc.move(to: launch)
            arc.addQuadCurve(to: landing, control: control)

            guard animated else {
                context.stroke(
                    arc,
                    with     : .color(FederationChoreography.accent.opacity(0.2)),
                    lineWidth: 1.5
                )
                continue
            }

            guard let progress = hop.progress(at: time) else { continue }

            context.stroke(
                arc,
                with     : .color(FederationChoreography.accent.opacity(FederationChoreography.arcOpacity(at: progress))),
                lineWidth: 1.5
            )

            paintPulse(
                into   : &context,
                from   : launch,
                to     : landing,
                control: control,
                at     : progress
            )
        }
    }

    /// Paints the travelling message: a bright core wrapped in two dimmer haloes, trailed by a
    /// short comet made of the positions it occupied a few hundredths of a second ago.
    private func paintPulse(
        into context: inout GraphicsContext,
        from origin : CGPoint,
        to target   : CGPoint,
        control     : CGPoint,
        at progress : Double
    ) {

        let eased = FederationChoreography.eased(progress)

        for trail in FederationChoreography.trail {

            let point = FederationChoreography.bezierPoint(
                from   : origin,
                to     : target,
                control: control,
                at     : max(0, eased - trail.lag)
            )

            context.fill(
                dot(
                    at      : point,
                    diameter: trail.diameter
                ),
                with: .color(FederationChoreography.accent.opacity(trail.opacity))
            )
        }
    }

    /// Builds the circle a pulse or one of its trailing dots is painted with, centred on `point`.
    private func dot(
        at point: CGPoint,
        diameter: CGFloat
    ) -> Path {

        Path(
            ellipseIn: CGRect(
                x     : point.x - diameter / 2,
                y     : point.y - diameter / 2,
                width : diameter,
                height: diameter
            )
        )
    }
}


/// One homeserver in the constellation: where it sits, how big it is, how it drifts.
private struct FederationNode {

    /// Position inside the view, normalized so the same layout survives any width.
    let center: CGPoint

    /// Side of the rounded square, in points.
    let side: CGFloat

    /// Horizontal drift cycles completed over one loop. Whole numbers only, otherwise the node
    /// would not be back where it started when the timeline wraps.
    let driftX: Double

    /// Vertical drift cycles completed over one loop, same whole number rule as `driftX`.
    let driftY: Double

    /// Head start that keeps this node out of step with its neighbours.
    let phase: Double
}


/// A message crossing from one homeserver to another during the loop.
private struct FederationHop {

    /// Index of the sending node inside `FederationChoreography.nodes`.
    let from: Int

    /// Index of the receiving node.
    let to: Int

    /// Second inside the loop when the pulse leaves.
    let start: Double

    /// How long the crossing takes, in seconds.
    let duration: Double

    /// Second inside the loop when the pulse lands, which is also when the receiver bounces.
    var arrival: Double { start + duration }

    /// How far along the pulse is, or nothing at all while this hop is not in flight.
    func progress(at time: Double) -> Double? {

        let elapsed = time - start
        guard elapsed >= 0, elapsed <= duration else { return nil }
        return elapsed / duration
    }
}


/// One glow of the backdrop: a pool of accent light behind the constellation.
private struct FederationGlow {

    /// Position inside the view, normalized like the nodes.
    let center: CGPoint

    /// Radius where the glow has fully faded out, as a fraction of the view's shorter side.
    let radius: CGFloat

    /// Opacity of the accent at the very centre of the glow.
    let opacity: Double

    /// Horizontal drift cycles completed over one loop, whole numbers so the wrap is seamless.
    let driftX: Double

    /// Vertical drift cycles completed over one loop, same whole number rule.
    let driftY: Double

    /// Head start that keeps this glow out of step with the others.
    let phase: Double
}


/// One dot of the comet: how far behind the pulse it lags, and how faint it is.
private struct FederationTrailDot {

    /// Distance behind the pulse, expressed in eased progress rather than seconds so the comet
    /// stretches and squashes with the pulse itself.
    let lag: Double

    /// Diameter in points.
    let diameter: CGFloat

    /// Opacity of the accent it is filled with.
    let opacity: Double
}


/// Every number that shapes the animation, gathered in one place so the composition can be
/// retuned without reading a single line of drawing code.
private enum FederationChoreography {

    /// Length of one full cycle in seconds. Short enough to be noticed, long enough that the eye
    /// never feels hurried.
    static let loop: Double = 8

    /// Height the view claims, chosen so the ring breathes between the onboarding header and the
    /// buttons underneath.
    static let height: CGFloat = 240

    /// The teal the whole composition is drawn in, `#00D5C7`.
    static let accent = Color(
        red  : 0.0,
        green: 0.835,
        blue : 0.780
    )

    /// Bright end of the app icon gradient, `#17E5D6`.
    static let logoLight = Color(
        red  : 0.09,
        green: 0.90,
        blue : 0.84
    )

    /// Dark end of the app icon gradient, `#00A79C`. Doubles as the ink for anything drawn on top
    /// of a light fill, where the accent itself would wash out.
    static let logoDeep = Color(
        red  : 0.0,
        green: 0.655,
        blue : 0.612
    )

    /// Where the icon gradient starts. The two unit points together describe a 160 degree sweep,
    /// the same angle the app icon uses.
    static let logoStart = UnitPoint(x: 0.33, y: 0.03)

    /// Where the icon gradient ends.
    static let logoEnd = UnitPoint(x: 0.67, y: 0.97)

    /// Which node belongs to the user. First, so the reading order starts there.
    static let userIndex = 0

    /// How far a node wanders from its resting spot, in points.
    static let floatAmplitude: Double = 3

    /// How far out of the ring an arc pushes its control point, as a fraction of the shorter side.
    static let arcBow: CGFloat = 0.12

    /// Peak opacity an arc holds while its pulse is mid flight.
    static let arcHold: Double = 0.35

    /// How far a glow wanders from its resting spot, in points. Wider than the nodes' float so the
    /// background feels like a different, slower layer of the same weather.
    static let glowDrift: Double = 14

    /// The pools of accent light behind the constellation: one broad wash off centre, two smaller
    /// ones balancing the corners the ring leaves empty.
    static let glows: [FederationGlow] = [
        FederationGlow(
            center : CGPoint(x: 0.40, y: 0.42),
            radius : 0.85,
            opacity: 0.10,
            driftX : 1,
            driftY : 1,
            phase  : 0.0
        ),
        FederationGlow(
            center : CGPoint(x: 0.88, y: 0.72),
            radius : 0.55,
            opacity: 0.09,
            driftX : 2,
            driftY : 1,
            phase  : 2.1
        ),
        FederationGlow(
            center : CGPoint(x: 0.10, y: 0.10),
            radius : 0.50,
            opacity: 0.08,
            driftX : 1,
            driftY : 2,
            phase  : 4.2
        )
    ]

    /// The five homeservers, on purpose not a clean pentagon: a slightly crooked ring reads as a
    /// handful of independent machines rather than a diagram.
    static let nodes: [FederationNode] = [
        FederationNode(
            center: CGPoint(x: 0.500, y: 0.140),
            side  : 54,
            driftX: 1,
            driftY: 2,
            phase : 0.0
        ),
        FederationNode(
            center: CGPoint(x: 0.880, y: 0.360),
            side  : 36,
            driftX: 2,
            driftY: 1,
            phase : 1.1
        ),
        FederationNode(
            center: CGPoint(x: 0.715, y: 0.865),
            side  : 33,
            driftX: 1,
            driftY: 3,
            phase : 2.3
        ),
        FederationNode(
            center: CGPoint(x: 0.240, y: 0.895),
            side  : 37,
            driftX: 3,
            driftY: 1,
            phase : 0.7
        ),
        FederationNode(
            center: CGPoint(x: 0.085, y: 0.345),
            side  : 34,
            driftX: 2,
            driftY: 2,
            phase : 3.4
        )
    ]

    /// The traffic of one loop. Every server both sends and receives, two hops leave the user's
    /// node out of it entirely, a relay never forwards before the message it forwards has landed,
    /// and the last arrival is early enough that its bounce dies out before the cycle restarts.
    static let hops: [FederationHop] = [
        FederationHop(
            from    : 0,
            to      : 1,
            start   : 0.15,
            duration: 1.20
        ),
        FederationHop(
            from    : 1,
            to      : 2,
            start   : 1.45,
            duration: 1.15
        ),
        FederationHop(
            from    : 4,
            to      : 3,
            start   : 2.20,
            duration: 1.25
        ),
        FederationHop(
            from    : 3,
            to      : 0,
            start   : 3.55,
            duration: 1.20
        ),
        FederationHop(
            from    : 2,
            to      : 4,
            start   : 4.10,
            duration: 1.30
        ),
        FederationHop(
            from    : 0,
            to      : 2,
            start   : 5.60,
            duration: 1.20
        )
    ]

    /// The pulse and its comet, in painting order: the two wide haloes that fake a glow, then the
    /// dots it left behind, then the bright core on top of all of them.
    static let trail: [FederationTrailDot] = [
        FederationTrailDot(
            lag     : 0.00,
            diameter: 12.0,
            opacity : 0.14
        ),
        FederationTrailDot(
            lag     : 0.00,
            diameter: 8.0,
            opacity : 0.22
        ),
        FederationTrailDot(
            lag     : 0.045,
            diameter: 3.6,
            opacity : 0.45
        ),
        FederationTrailDot(
            lag     : 0.090,
            diameter: 2.8,
            opacity : 0.28
        ),
        FederationTrailDot(
            lag     : 0.135,
            diameter: 2.0,
            opacity : 0.15
        ),
        FederationTrailDot(
            lag     : 0.00,
            diameter: 4.5,
            opacity : 0.95
        )
    ]

    /// Centre of gravity of the ring in normalized space, the point every arc bows away from.
    static let centroid: CGPoint = {

        let total = nodes.reduce(into: CGPoint.zero) { sum, node in
            sum.x += node.center.x
            sum.y += node.center.y
        }
        return CGPoint(
            x: total.x / CGFloat(nodes.count),
            y: total.y / CGFloat(nodes.count)
        )
    }()

    /// Where inside the loop the given instant falls. Folding wall clock time this way means two
    /// instances of the view are always in step, and no frame can ever be skipped or replayed.
    static func time(of date: Date) -> Double {

        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: loop)
    }

    /// Screen position of a node, drifting or at rest.
    static func position(
        of node : FederationNode,
        in size : CGSize,
        at time : Double,
        floating: Bool
    ) -> CGPoint {

        let resting = CGPoint(
            x: node.center.x * size.width,
            y: node.center.y * size.height
        )
        guard floating else { return resting }

        let turn = 2 * Double.pi * time / loop
        return CGPoint(
            x: resting.x + sin(turn * node.driftX + node.phase) * floatAmplitude,
            y: resting.y + cos(turn * node.driftY + node.phase) * floatAmplitude
        )
    }

    /// Screen position of a glow, drifting on its own slow cycle or at rest.
    static func glowCenter(
        of glow : FederationGlow,
        in size : CGSize,
        at time : Double,
        floating: Bool
    ) -> CGPoint {

        let resting = CGPoint(
            x: glow.center.x * size.width,
            y: glow.center.y * size.height
        )
        guard floating else { return resting }

        let turn = 2 * Double.pi * time / loop
        return CGPoint(
            x: resting.x + sin(turn * glow.driftX + glow.phase) * glowDrift,
            y: resting.y + cos(turn * glow.driftY + glow.phase) * glowDrift
        )
    }

    /// Control point that bows a hop away from the middle of the ring, so arcs never cut across
    /// the constellation in a straight line.
    static func control(
        from origin: CGPoint,
        to target  : CGPoint,
        in size    : CGSize
    ) -> CGPoint {

        let middle = CGPoint(
            x: (origin.x + target.x) / 2,
            y: (origin.y + target.y) / 2
        )
        let hub = CGPoint(
            x: centroid.x * size.width,
            y: centroid.y * size.height
        )

        var awayX = middle.x - hub.x
        var awayY = middle.y - hub.y
        var length = sqrt(awayX * awayX + awayY * awayY)

        // A hop straight across the ring has its midpoint sitting on the centroid, so there is no
        // outward direction to follow. Bow it sideways instead of dividing by nothing.
        if length < 0.5 {
            awayX = -(target.y - origin.y)
            awayY = target.x - origin.x
            length = sqrt(awayX * awayX + awayY * awayY)
        }
        guard length > 0 else { return middle }

        let push = arcBow * min(size.width, size.height)
        return CGPoint(
            x: middle.x + awayX / length * push,
            y: middle.y + awayY / length * push
        )
    }

    /// Slides a node's centre out to the edge of its box, along the line towards the control point
    /// of the arc that is about to leave or land there.
    static func rim(
        of point     : CGPoint,
        facing pull  : CGPoint,
        clearing side: CGFloat
    ) -> CGPoint {

        let towardX = pull.x - point.x
        let towardY = pull.y - point.y
        let length = sqrt(towardX * towardX + towardY * towardY)
        guard length > 0 else { return point }

        let step = min(side / 2 + 4, length)
        return CGPoint(
            x: point.x + towardX / length * step,
            y: point.y + towardY / length * step
        )
    }

    /// Point on the quadratic curve of a hop at the given progress.
    static func bezierPoint(
        from origin: CGPoint,
        to target  : CGPoint,
        control    : CGPoint,
        at progress: Double
    ) -> CGPoint {

        let rest = 1 - progress
        let originWeight = rest * rest
        let controlWeight = 2 * rest * progress
        let targetWeight = progress * progress

        return CGPoint(
            x: origin.x * originWeight + control.x * controlWeight + target.x * targetWeight,
            y: origin.y * originWeight + control.y * controlWeight + target.y * targetWeight
        )
    }

    /// Ease in out over a hop, so a pulse leaves gently, crosses quickly and settles into its
    /// destination instead of slamming into it.
    static func eased(_ progress: Double) -> Double {

        progress < 0.5
        ? 2 * progress * progress
        : 1 - pow(-2 * progress + 2, 2) / 2
    }

    /// Opacity of an arc as its pulse crosses: a trapezoid, drawn on ahead of the pulse and swept
    /// away behind it.
    static func arcOpacity(at progress: Double) -> Double {

        if progress < 0.2 { return arcHold * progress / 0.2 }
        if progress > 0.75 { return arcHold * (1 - progress) / 0.25 }
        return arcHold
    }

    /// Scale a node is drawn at: the bounce of everything that just landed on it, plus a slow
    /// breath for the user's own server.
    static func liveliness(
        of index: Int,
        at time : Double
    ) -> CGFloat {

        var scale = bounce(
            of: index,
            at: time
        )
        if index == userIndex { scale *= breath(at: time) }
        return scale
    }

    /// Arrival kick, an exponentially damped sine so the node overshoots once, wobbles and is done
    /// well inside a second. Silent until the message actually lands.
    static func bounce(
        of index: Int,
        at time : Double
    ) -> CGFloat {

        var scale: Double = 1

        for hop in hops where hop.to == index {
            let since = time - hop.arrival
            guard since >= 0, since < 0.9 else { continue }
            scale += 0.14 * exp(-4.5 * since) * sin(2 * Double.pi * since / 0.36)
        }
        return CGFloat(scale)
    }

    /// The user's server inhaling and exhaling once every four seconds, two whole cycles per loop
    /// so it wraps without a jolt.
    static func breath(at time: Double) -> CGFloat {

        CGFloat(1 + 0.01 * (1 - cos(2 * Double.pi * time * 2 / loop)))
    }
}
