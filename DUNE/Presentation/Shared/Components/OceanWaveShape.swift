import SwiftUI

// MARK: - Shared Wave Computation

/// Pre-computed sample points for wave rendering.
/// Shared across all wave shape variants to avoid duplication.
struct WaveSamples {
    let points: [(x: CGFloat, angle: CGFloat)]
    static let sampleCount = 120

    init(frequency: CGFloat) {
        let count = Self.sampleCount
        var pts: [(x: CGFloat, angle: CGFloat)] = []
        pts.reserveCapacity(count + 1)
        for i in 0...count {
            let x = CGFloat(i) / CGFloat(count)
            let angle = x * frequency * 2 * .pi
            pts.append((x: x, angle: angle))
        }
        self.points = pts
    }
}

/// Phase-scaling constants for wave harmonics.
/// - `envelopeDrift`: Slow drift for low-frequency envelope (breaks periodicity)
/// - `sharpnessDrift`: Faster drift for high-frequency crest detail
private enum HarmonicPhase {
    static let envelopeDrift: CGFloat = 0.3
    static let sharpnessDrift: CGFloat = 1.5
}

/// Single wave y-value computation shared by all shape variants.
@inline(__always)
private func waveY(
    angle: CGFloat,
    phase: CGFloat,
    centerY: CGFloat,
    amp: CGFloat,
    steepness: CGFloat,
    harmonicOffset: CGFloat,
    crestHeight: CGFloat,
    crestSharpness: CGFloat
) -> CGFloat {
    let primary = sin(angle + phase)
    let harmonic = steepness * sin(2 * angle + phase + harmonicOffset)
    let envelope = crestHeight * sin(0.5 * angle + phase * HarmonicPhase.envelopeDrift)
    let sharpness = crestSharpness * sin(3 * angle + phase * HarmonicPhase.sharpnessDrift)
    return centerY + amp * (primary + harmonic + envelope + sharpness)
}

/// Pre-compute all Y values for sample points.
/// Used when curl detection is needed to avoid double computation.
@inline(__always)
private func computeWaveYValues(
    samples: WaveSamples,
    phase: CGFloat,
    centerY: CGFloat,
    amp: CGFloat,
    steepness: CGFloat,
    harmonicOffset: CGFloat,
    crestHeight: CGFloat,
    crestSharpness: CGFloat
) -> [CGFloat] {
    var yVals = [CGFloat]()
    yVals.reserveCapacity(samples.points.count)
    for pt in samples.points {
        yVals.append(waveY(
            angle: pt.angle, phase: phase,
            centerY: centerY, amp: amp,
            steepness: steepness, harmonicOffset: harmonicOffset,
            crestHeight: crestHeight, crestSharpness: crestSharpness
        ))
    }
    return yVals
}

// MARK: - Curl Computation

/// Anchor points for a single curl drawn above a wave crest.
private struct CurlAnchor {
    let startX: CGFloat
    let startY: CGFloat
    let peakX: CGFloat
    let curlPeakY: CGFloat
    let lipX: CGFloat
    let lipY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
}

/// Finds wave crests and computes curl anchor points.
/// Accepts pre-computed Y values to avoid redundant trig computation.
/// Returns up to `curlCount` anchors sorted left-to-right.
private func computeCurlAnchors(
    yVals: [CGFloat],
    samples: WaveSamples,
    rect: CGRect,
    amp: CGFloat,
    curlCount: Int,
    curlHeight: CGFloat,
    curlWidth: CGFloat
) -> [CurlAnchor] {
    let pts = samples.points
    let count = pts.count

    // Find local minima in Y (visual peaks) with strict 2-neighbor check
    var crests: [(index: Int, y: CGFloat)] = []
    for i in 2..<(count - 2) {
        if yVals[i] < yVals[i - 1] && yVals[i] < yVals[i + 1]
            && yVals[i] < yVals[i - 2] && yVals[i] < yVals[i + 2]
        {
            crests.append((i, yVals[i]))
        }
    }

    guard !crests.isEmpty else { return [] }

    // Select top N (lowest Y = tallest visual peak)
    let selected = Array(crests.sorted { $0.y < $1.y }.prefix(curlCount))

    let halfWidth = Swift.max(4, Int(curlWidth * CGFloat(count) / 2))
    let curlAmp = curlHeight * amp

    var anchors: [CurlAnchor] = []
    for crest in selected {
        let ci = crest.index
        let startIdx = Swift.max(0, ci - halfWidth)
        let endIdx = Swift.min(count - 1, ci + halfWidth)
        let lipIdx = Swift.min(ci + halfWidth * 2 / 3, endIdx)

        let peakBaseY = yVals[ci]

        anchors.append(CurlAnchor(
            startX: pts[startIdx].x * rect.width,
            startY: yVals[startIdx],
            peakX: pts[ci].x * rect.width,
            curlPeakY: peakBaseY - curlAmp,
            lipX: pts[lipIdx].x * rect.width,
            lipY: peakBaseY - curlAmp * 0.15,
            endX: pts[endIdx].x * rect.width,
            endY: yVals[endIdx]
        ))
    }

    anchors.sort { $0.startX < $1.startX }
    return anchors
}

/// Shared rise→lip→descent Bezier curve for curl top edge.
/// Extracted to satisfy DRY (3 callers: fill, stroke, foam).
@inline(__always)
private func addCurlTopEdge(
    to path: inout Path,
    anchor a: CurlAnchor,
    curlAmp: CGFloat
) {
    // Rise: wave line → peak
    let riseDx = a.peakX - a.startX
    path.addCurve(
        to: CGPoint(x: a.peakX, y: a.curlPeakY),
        control1: CGPoint(x: a.startX + riseDx * 0.5, y: a.startY),
        control2: CGPoint(x: a.peakX - riseDx * 0.15, y: a.curlPeakY + curlAmp * 0.15)
    )

    // Lip: peak → lip end (curling forward)
    let lipDx = a.lipX - a.peakX
    path.addCurve(
        to: CGPoint(x: a.lipX, y: a.lipY),
        control1: CGPoint(x: a.peakX + lipDx * 0.5, y: a.curlPeakY - curlAmp * 0.03),
        control2: CGPoint(x: a.lipX - lipDx * 0.2, y: a.lipY - curlAmp * 0.12)
    )

    // Descent: lip → wave line
    let descDx = a.endX - a.lipX
    let descDy = a.endY - a.lipY
    path.addCurve(
        to: CGPoint(x: a.endX, y: a.endY),
        control1: CGPoint(x: a.lipX + descDx * 0.3, y: a.lipY + descDy * 0.5),
        control2: CGPoint(x: a.endX - descDx * 0.3, y: a.endY)
    )
}

/// Adds curl Bezier subpaths to a fill path (closed subpaths).
@inline(__always)
private func addCurlFillSubpaths(
    to path: inout Path,
    anchors: [CurlAnchor],
    curlAmp: CGFloat
) {
    for a in anchors {
        path.move(to: CGPoint(x: a.startX, y: a.startY))
        addCurlTopEdge(to: &path, anchor: a, curlAmp: curlAmp)
        path.closeSubpath()
    }
}

/// Adds curl Bezier subpaths to a stroke path (open subpaths).
@inline(__always)
private func addCurlStrokeSubpaths(
    to path: inout Path,
    anchors: [CurlAnchor],
    curlAmp: CGFloat
) {
    for a in anchors {
        path.move(to: CGPoint(x: a.startX, y: a.startY))
        addCurlTopEdge(to: &path, anchor: a, curlAmp: curlAmp)
    }
}

/// Adds curl foam band subpaths (closed, with offset bottom edge).
@inline(__always)
private func addCurlFoamSubpaths(
    to path: inout Path,
    anchors: [CurlAnchor],
    curlAmp: CGFloat,
    foamH: CGFloat
) {
    for a in anchors {
        // Forward pass: top edge (shared helper)
        path.move(to: CGPoint(x: a.startX, y: a.startY))
        addCurlTopEdge(to: &path, anchor: a, curlAmp: curlAmp)

        // Reverse pass: bottom edge (offset by foamH)
        let riseDx = a.peakX - a.startX
        let lipDx = a.lipX - a.peakX
        let descDx = a.endX - a.lipX
        let descDy = a.endY - a.lipY

        path.addCurve(
            to: CGPoint(x: a.lipX, y: a.lipY + foamH),
            control1: CGPoint(x: a.endX - descDx * 0.3, y: a.endY + foamH),
            control2: CGPoint(x: a.lipX + descDx * 0.3, y: a.lipY + descDy * 0.5 + foamH)
        )

        path.addCurve(
            to: CGPoint(x: a.peakX, y: a.curlPeakY + foamH),
            control1: CGPoint(x: a.lipX - lipDx * 0.2, y: a.lipY - curlAmp * 0.12 + foamH),
            control2: CGPoint(x: a.peakX + lipDx * 0.5, y: a.curlPeakY - curlAmp * 0.03 + foamH)
        )

        path.addCurve(
            to: CGPoint(x: a.startX, y: a.startY + foamH),
            control1: CGPoint(x: a.peakX - riseDx * 0.15, y: a.curlPeakY + curlAmp * 0.15 + foamH),
            control2: CGPoint(x: a.startX + riseDx * 0.5, y: a.startY + foamH)
        )

        path.closeSubpath()
    }
}

// MARK: - Fill Shape

/// Asymmetric ocean-wave Shape with harmonic enrichment.
///
/// Combines a primary sine with higher harmonics to create sharp crests,
/// gentle troughs, and variable wave heights — matching Japanese-style
/// ocean wave silhouettes.
///
/// Pre-computes normalised angles at init; `path(in:)` only evaluates
/// four `sin()` calls per sample point and scales to rect.
///
/// When `curlCount > 0`, dramatic curling crests are added at the tallest
/// wave peaks as additional Bezier subpaths, synchronized with the wave phase.
struct OceanWaveShape: Shape {
    let amplitude: CGFloat
    let frequency: CGFloat
    var phase: CGFloat
    let verticalOffset: CGFloat
    let steepness: CGFloat
    let harmonicOffset: CGFloat
    let crestHeight: CGFloat
    let crestSharpness: CGFloat
    let curlCount: Int
    let curlHeight: CGFloat
    let curlWidth: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private let samples: WaveSamples

    init(
        amplitude: CGFloat = 0.05,
        frequency: CGFloat = 2,
        phase: CGFloat = 0,
        verticalOffset: CGFloat = 0.5,
        steepness: CGFloat = 0.3,
        harmonicOffset: CGFloat = .pi / 4,
        crestHeight: CGFloat = 0,
        crestSharpness: CGFloat = 0,
        curlCount: Int = 0,
        curlHeight: CGFloat = 1.5,
        curlWidth: CGFloat = 0.1
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.steepness = steepness
        self.harmonicOffset = harmonicOffset
        self.crestHeight = Swift.min(crestHeight, 0.4)
        self.crestSharpness = Swift.min(crestSharpness, 0.15)
        self.curlCount = Swift.max(0, Swift.min(curlCount, 5))
        self.curlHeight = Swift.max(0, curlHeight)
        self.curlWidth = Swift.max(0.03, Swift.min(curlWidth, 1.0))
        self.samples = WaveSamples(frequency: frequency)
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset

        var path = Path()

        if curlCount > 0, amp > 0 {
            // Pre-compute Y values once for both contour + curl detection
            let yVals = computeWaveYValues(
                samples: samples, phase: phase, centerY: centerY, amp: amp,
                steepness: steepness, harmonicOffset: harmonicOffset,
                crestHeight: crestHeight, crestSharpness: crestSharpness
            )

            for (i, pt) in samples.points.enumerated() {
                let x = pt.x * rect.width
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: yVals[i]))
                } else {
                    path.addLine(to: CGPoint(x: x, y: yVals[i]))
                }
            }

            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()

            let anchors = computeCurlAnchors(
                yVals: yVals, samples: samples, rect: rect, amp: amp,
                curlCount: curlCount, curlHeight: curlHeight, curlWidth: curlWidth
            )
            addCurlFillSubpaths(to: &path, anchors: anchors, curlAmp: curlHeight * amp)
        } else {
            // Standard inline computation (no curl, no array allocation)
            for (i, pt) in samples.points.enumerated() {
                let x = pt.x * rect.width
                let y = waveY(
                    angle: pt.angle, phase: phase,
                    centerY: centerY, amp: amp,
                    steepness: steepness, harmonicOffset: harmonicOffset,
                    crestHeight: crestHeight, crestSharpness: crestSharpness
                )

                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }

        return path
    }
}

// MARK: - Stroke Shape

/// Renders only the wave line (no fill), for crest highlight strokes.
/// Uses the shared wave formula and sample points.
/// When `curlCount > 0`, adds curl stroke paths at tallest crests.
struct OceanWaveStrokeShape: Shape {
    let amplitude: CGFloat
    let frequency: CGFloat
    var phase: CGFloat
    let verticalOffset: CGFloat
    let steepness: CGFloat
    let harmonicOffset: CGFloat
    let crestHeight: CGFloat
    let crestSharpness: CGFloat
    let curlCount: Int
    let curlHeight: CGFloat
    let curlWidth: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private let samples: WaveSamples

    init(
        amplitude: CGFloat = 0.05,
        frequency: CGFloat = 2,
        phase: CGFloat = 0,
        verticalOffset: CGFloat = 0.5,
        steepness: CGFloat = 0.3,
        harmonicOffset: CGFloat = .pi / 4,
        crestHeight: CGFloat = 0,
        crestSharpness: CGFloat = 0,
        curlCount: Int = 0,
        curlHeight: CGFloat = 1.5,
        curlWidth: CGFloat = 0.1
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.steepness = steepness
        self.harmonicOffset = harmonicOffset
        self.crestHeight = Swift.min(crestHeight, 0.4)
        self.crestSharpness = Swift.min(crestSharpness, 0.15)
        self.curlCount = Swift.max(0, Swift.min(curlCount, 5))
        self.curlHeight = Swift.max(0, curlHeight)
        self.curlWidth = Swift.max(0.03, Swift.min(curlWidth, 1.0))
        self.samples = WaveSamples(frequency: frequency)
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset

        var path = Path()

        if curlCount > 0, amp > 0 {
            let yVals = computeWaveYValues(
                samples: samples, phase: phase, centerY: centerY, amp: amp,
                steepness: steepness, harmonicOffset: harmonicOffset,
                crestHeight: crestHeight, crestSharpness: crestSharpness
            )

            for (i, pt) in samples.points.enumerated() {
                let x = pt.x * rect.width
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: yVals[i]))
                } else {
                    path.addLine(to: CGPoint(x: x, y: yVals[i]))
                }
            }

            let anchors = computeCurlAnchors(
                yVals: yVals, samples: samples, rect: rect, amp: amp,
                curlCount: curlCount, curlHeight: curlHeight, curlWidth: curlWidth
            )
            addCurlStrokeSubpaths(to: &path, anchors: anchors, curlAmp: curlHeight * amp)
        } else {
            for (i, pt) in samples.points.enumerated() {
                let x = pt.x * rect.width
                let y = waveY(
                    angle: pt.angle, phase: phase,
                    centerY: centerY, amp: amp,
                    steepness: steepness, harmonicOffset: harmonicOffset,
                    crestHeight: crestHeight, crestSharpness: crestSharpness
                )

                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }

        return path
    }
}

// MARK: - Foam Gradient Shape

/// Thin gradient band at wave crests: white fading downward.
/// Uses the shared wave formula; no intermediate array allocation.
/// When `curlCount > 0`, adds curl foam bands at tallest crests.
struct OceanFoamGradientShape: Shape {
    let amplitude: CGFloat
    let frequency: CGFloat
    var phase: CGFloat
    let verticalOffset: CGFloat
    let steepness: CGFloat
    let harmonicOffset: CGFloat
    let crestHeight: CGFloat
    let crestSharpness: CGFloat
    /// Height of foam band as fraction of rect height.
    let foamDepth: CGFloat
    let curlCount: Int
    let curlHeight: CGFloat
    let curlWidth: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private let samples: WaveSamples

    init(
        amplitude: CGFloat = 0.05,
        frequency: CGFloat = 2,
        phase: CGFloat = 0,
        verticalOffset: CGFloat = 0.5,
        steepness: CGFloat = 0.3,
        harmonicOffset: CGFloat = .pi / 4,
        crestHeight: CGFloat = 0,
        crestSharpness: CGFloat = 0,
        foamDepth: CGFloat = 0.03,
        curlCount: Int = 0,
        curlHeight: CGFloat = 1.5,
        curlWidth: CGFloat = 0.1
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.steepness = steepness
        self.harmonicOffset = harmonicOffset
        self.crestHeight = Swift.min(crestHeight, 0.4)
        self.crestSharpness = Swift.min(crestSharpness, 0.15)
        self.foamDepth = foamDepth
        self.curlCount = Swift.max(0, Swift.min(curlCount, 5))
        self.curlHeight = Swift.max(0, curlHeight)
        self.curlWidth = Swift.max(0.03, Swift.min(curlWidth, 1.0))
        self.samples = WaveSamples(frequency: frequency)
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset
        let foamH = rect.height * foamDepth
        let pts = samples.points

        var path = Path()

        if curlCount > 0, amp > 0 {
            let yVals = computeWaveYValues(
                samples: samples, phase: phase, centerY: centerY, amp: amp,
                steepness: steepness, harmonicOffset: harmonicOffset,
                crestHeight: crestHeight, crestSharpness: crestSharpness
            )

            // Forward pass: top edge (wave line)
            for (i, pt) in pts.enumerated() {
                let x = pt.x * rect.width
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: yVals[i]))
                } else {
                    path.addLine(to: CGPoint(x: x, y: yVals[i]))
                }
            }

            // Reverse pass: bottom edge (shifted down by foamDepth)
            for (j, pt) in pts.enumerated().reversed() {
                let x = pt.x * rect.width
                path.addLine(to: CGPoint(x: x, y: yVals[j] + foamH))
            }
            path.closeSubpath()

            let anchors = computeCurlAnchors(
                yVals: yVals, samples: samples, rect: rect, amp: amp,
                curlCount: curlCount, curlHeight: curlHeight, curlWidth: curlWidth
            )
            addCurlFoamSubpaths(
                to: &path, anchors: anchors,
                curlAmp: curlHeight * amp, foamH: foamH
            )
        } else {
            // Forward pass: top edge (wave line)
            for (i, pt) in pts.enumerated() {
                let x = pt.x * rect.width
                let y = waveY(
                    angle: pt.angle, phase: phase,
                    centerY: centerY, amp: amp,
                    steepness: steepness, harmonicOffset: harmonicOffset,
                    crestHeight: crestHeight, crestSharpness: crestSharpness
                )
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            // Reverse pass: bottom edge (shifted down by foamDepth)
            for pt in pts.reversed() {
                let x = pt.x * rect.width
                let y = waveY(
                    angle: pt.angle, phase: phase,
                    centerY: centerY, amp: amp,
                    steepness: steepness, harmonicOffset: harmonicOffset,
                    crestHeight: crestHeight, crestSharpness: crestSharpness
                ) + foamH
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.closeSubpath()
        }

        return path
    }
}

// MARK: - Ocean Wave Overlay (Multi-speed, Directional)

/// Animated ocean wave overlay with configurable drift speed and direction.
/// Set `curlCount > 0` to add dramatic curling crests at wave peaks.
struct OceanWaveOverlayView: View {
    var color: Color
    var opacity: Double
    var amplitude: CGFloat
    var frequency: CGFloat
    var verticalOffset: CGFloat = 0.5
    var bottomFade: CGFloat = 0
    var steepness: CGFloat = 0.3
    var harmonicOffset: CGFloat = .pi / 4
    var crestHeight: CGFloat = 0
    var crestSharpness: CGFloat = 0
    /// Duration of one full phase cycle (seconds). Slower = more distant wave.
    var driftDuration: TimeInterval = 6
    /// Drift direction. Reverse creates cross-current depth effect.
    var reverseDirection: Bool = false
    /// White stroke along wave crest line.
    var strokeStyle: WaveStrokeStyle? = nil
    /// Foam gradient band below crest.
    var foamStyle: WaveFoamStyle? = nil
    /// Number of curl crests to display (0 = none).
    var curlCount: Int = 0
    /// Height of curl relative to wave amplitude.
    var curlHeight: CGFloat = 1.5
    /// Width of curl region as fraction of total width.
    var curlWidth: CGFloat = 0.1

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Fill layer
            OceanWaveShape(
                amplitude: amplitude,
                frequency: frequency,
                phase: phase,
                verticalOffset: verticalOffset,
                steepness: steepness,
                harmonicOffset: harmonicOffset,
                crestHeight: crestHeight,
                crestSharpness: crestSharpness,
                curlCount: curlCount,
                curlHeight: curlHeight,
                curlWidth: curlWidth
            )
            .fill(fillColor)

            // Foam gradient layer
            if let foam = foamStyle {
                OceanFoamGradientShape(
                    amplitude: amplitude,
                    frequency: frequency,
                    phase: phase,
                    verticalOffset: verticalOffset,
                    steepness: steepness,
                    harmonicOffset: harmonicOffset,
                    crestHeight: crestHeight,
                    crestSharpness: crestSharpness,
                    foamDepth: foam.depth,
                    curlCount: curlCount,
                    curlHeight: curlHeight,
                    curlWidth: curlWidth
                )
                .fill(foam.gradient)
            }

            // Stroke layer
            if let stroke = strokeStyle {
                OceanWaveStrokeShape(
                    amplitude: amplitude,
                    frequency: frequency,
                    phase: phase,
                    verticalOffset: verticalOffset,
                    steepness: steepness,
                    harmonicOffset: harmonicOffset,
                    crestHeight: crestHeight,
                    crestSharpness: crestSharpness,
                    curlCount: curlCount,
                    curlHeight: curlHeight,
                    curlWidth: curlWidth
                )
                .stroke(stroke.resolvedColor, lineWidth: stroke.width)
            }
        }
        .clipped()
        .mask {
            if bottomFade > 0 {
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 1.0 - bottomFade),
                        .init(color: .white.opacity(0), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Rectangle()
            }
        }
        .allowsHitTesting(false)
        .task {
            guard !reduceMotion, driftDuration > 0 else { return }
            let target: CGFloat = reverseDirection ? -(2 * .pi) : (2 * .pi)
            withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                phase = target
            }
        }
    }

    // Pre-compute fill color to avoid allocation in body during animation
    private var fillColor: Color { color.opacity(opacity) }
}

// MARK: - Style Types

/// Stroke style for wave crest highlight.
struct WaveStrokeStyle: Sendable {
    let color: Color
    let width: CGFloat
    let opacity: Double
    /// Pre-resolved color to avoid per-frame allocation.
    let resolvedColor: Color

    init(color: Color, width: CGFloat, opacity: Double) {
        self.color = color
        self.width = width
        self.opacity = opacity
        self.resolvedColor = color.opacity(opacity)
    }
}

/// Foam gradient style for wave crest band.
struct WaveFoamStyle: Sendable {
    let color: Color
    let opacity: Double
    let depth: CGFloat
    /// Pre-built gradient to avoid per-frame allocation.
    let gradient: LinearGradient

    init(color: Color, opacity: Double, depth: CGFloat) {
        self.color = color
        self.opacity = opacity
        self.depth = depth
        self.gradient = LinearGradient(
            colors: [color.opacity(opacity), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
