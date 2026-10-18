import SwiftUI

// The pond is a decorative scene. Its leaves remain legible without animation,
// and all three variants stay outside the accessibility and hit-test trees.
private enum WaterLiliesPalette {
    static let waterDeep = Color(red: 0.27, green: 0.49, blue: 0.67)
    static let waterMid = Color(red: 0.42, green: 0.66, blue: 0.73)
    static let waterLight = Color(red: 0.55, green: 0.79, blue: 0.78)
    static let reflection = Color(red: 0.75, green: 0.88, blue: 0.86)
    static let leafDark = Color(red: 0.25, green: 0.52, blue: 0.49)
    static let leafMid = Color(red: 0.43, green: 0.66, blue: 0.47)
    static let leafLight = Color(red: 0.71, green: 0.79, blue: 0.49)
    static let flowerDark = Color(red: 0.62, green: 0.40, blue: 0.74)
    static let flowerLight = Color(red: 0.77, green: 0.49, blue: 0.77)
}

private enum WaterLiliesSceneKind: Equatable {
    case tab
    case detail
    case sheet

    var height: CGFloat {
        switch self {
        case .tab: 250
        case .detail: 172
        case .sheet: 136
        }
    }

    var strength: Double {
        switch self {
        case .tab: 1
        case .detail: 0.60
        case .sheet: 0.38
        }
    }
}

private struct WaterLiliesScene: View {
    let kind: WaterLiliesSceneKind

    @Environment(\.wavePreset) private var preset
    @Environment(\.waveReducedMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isDrifting = false

    private var clusterCount: Int {
        switch kind {
        case .detail: 5
        case .sheet: 3
        case .tab:
            switch preset {
            case .today: 15
            case .train: 12
            case .wellness: 10
            case .life: 8
            }
        }
    }

    private var markCount: Int {
        switch kind {
        case .detail: 36
        case .sheet: 20
        case .tab:
            switch preset {
            case .today: 96
            case .train: 76
            case .wellness: 64
            case .life: 52
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    WaterLiliesPalette.waterDeep.opacity(colorScheme == .dark ? 0.36 : 0.27),
                    WaterLiliesPalette.waterMid.opacity(colorScheme == .dark ? 0.31 : 0.24),
                    WaterLiliesPalette.waterLight.opacity(0.16),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: kind.height)

            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                var drawing = context
                drawing.scaleBy(x: size.width / 400, y: size.height / 220)
                WaterLiliesPainting.draw(
                    in: &drawing,
                    clusters: clusterCount,
                    marks: markCount,
                    strength: kind.strength * (colorScheme == .dark ? 1.10 : 1)
                )
            }
            .frame(height: kind.height)
            .offset(x: isDrifting ? 5 : -5)
            .mask {
                LinearGradient(
                    colors: [.white, .white, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .ignoresSafeArea()
        .task(id: reduceMotion) {
            if reduceMotion || kind != .tab {
                isDrifting = false
            } else {
                isDrifting = false
                withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                    isDrifting = true
                }
            }
        }
    }
}

private enum WaterLiliesPainting {
    // Ordered to spread the first few clusters over the width for quieter presets.
    private static let placements: [(CGFloat, CGFloat, CGFloat, Bool)] = [
        (300, 82, 28, true), (105, 58, 25, false), (215, 138, 33, true),
        (367, 154, 29, false), (64, 139, 30, false), (246, 45, 24, false),
        (149, 107, 29, true), (340, 37, 22, false), (30, 80, 24, false),
        (270, 161, 30, false), (181, 39, 23, true), (383, 97, 25, true),
        (92, 190, 31, true), (326, 192, 30, false), (201, 91, 26, false)
    ]

    static func draw(in context: inout GraphicsContext, clusters: Int, marks: Int, strength: Double) {
        drawWater(in: &context, marks: marks, strength: strength)

        for index in 0..<min(clusters, placements.count) {
            let (x, y, size, hasFlower) = placements[index]
            drawLeaves(in: &context, x: x, y: y, size: size, strength: strength)
            if hasFlower {
                drawFlower(in: &context, x: x + size * 0.15, y: y - size * 0.29, strength: strength)
            }
        }
    }

    private static func drawWater(in context: inout GraphicsContext, marks: Int, strength: Double) {
        for index in 0..<marks {
            let seed = CGFloat(index)
            let x = (seed * 73.7).truncatingRemainder(dividingBy: 418) - 9
            let y = (seed * 43.3).truncatingRemainder(dividingBy: 195) + 8
            let length = 3 + (seed * 11.7).truncatingRemainder(dividingBy: 22)
            var stroke = Path()
            stroke.move(to: CGPoint(x: x, y: y))
            stroke.addQuadCurve(
                to: CGPoint(x: x + length, y: y - 0.7),
                control: CGPoint(x: x + length * 0.54, y: y - 2.3)
            )
            let color = index.isMultiple(of: 4)
                ? WaterLiliesPalette.reflection
                : (index.isMultiple(of: 3) ? WaterLiliesPalette.waterDeep : WaterLiliesPalette.waterLight)
            context.stroke(
                stroke,
                with: .color(color.opacity((index.isMultiple(of: 4) ? 0.43 : 0.27) * strength)),
                style: StrokeStyle(lineWidth: index.isMultiple(of: 7) ? 2.1 : 1.1, lineCap: .round)
            )
        }
    }

    private static func drawLeaves(
        in context: inout GraphicsContext,
        x: CGFloat,
        y: CGFloat,
        size: CGFloat,
        strength: Double
    ) {
        // Uneven overlapping strokes form a leaf island, rather than a circular pad.
        for strokeIndex in 0..<11 {
            let offset = CGFloat(strokeIndex - 5)
            let jitter = sin(CGFloat(strokeIndex) * 2.7 + x * 0.11) * size * 0.035
            let row = y + offset * size * 0.105 + jitter
            let left = x - size * (0.65 + 0.16 * abs(sin(CGFloat(strokeIndex) * 1.9)))
            let right = x + size * (0.43 + 0.28 * abs(cos(CGFloat(strokeIndex) * 1.4)))
            var leaf = Path()
            leaf.move(to: CGPoint(x: left, y: row))
            leaf.addQuadCurve(
                to: CGPoint(x: right, y: row + offset * 0.42),
                control: CGPoint(x: x + offset * 0.6, y: row - 3.1)
            )
            let color: Color
            switch strokeIndex % 3 {
            case 0: color = WaterLiliesPalette.leafDark
            case 1: color = WaterLiliesPalette.leafMid
            default: color = WaterLiliesPalette.leafLight
            }
            context.stroke(
                leaf,
                with: .color(color.opacity((0.48 + Double(strokeIndex % 4) * 0.10) * strength)),
                style: StrokeStyle(lineWidth: strokeIndex.isMultiple(of: 4) ? 5.2 : 2.9, lineCap: .round)
            )
        }
    }

    private static func drawFlower(in context: inout GraphicsContext, x: CGFloat, y: CGFloat, strength: Double) {
        for petal in 0..<5 {
            let shift = CGFloat(petal - 2) * 2.3
            var mark = Path()
            mark.move(to: CGPoint(x: x + shift, y: y + 3))
            mark.addQuadCurve(
                to: CGPoint(x: x + shift + CGFloat(petal - 2) * 0.5, y: y - 7 - CGFloat(petal % 2) * 2),
                control: CGPoint(x: x + shift + (petal.isMultiple(of: 2) ? -2 : 2), y: y - 3)
            )
            context.stroke(
                mark,
                with: .color((petal.isMultiple(of: 2) ? WaterLiliesPalette.flowerLight : WaterLiliesPalette.flowerDark)
                    .opacity(0.86 * strength)),
                style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
            )
        }
    }
}

/// Layered blue water and clustered water lilies for the four tab roots.
struct WaterLiliesTabWaveBackground: View {
    var body: some View { WaterLiliesScene(kind: .tab) }
}

/// A quieter pond motif for detail screens.
struct WaterLiliesDetailWaveBackground: View {
    var body: some View { WaterLiliesScene(kind: .detail) }
}

/// A nearly still pond accent for sheets and input flows.
struct WaterLiliesSheetWaveBackground: View {
    var body: some View { WaterLiliesScene(kind: .sheet) }
}
