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
    @Environment(\.scenePhase) private var scenePhase

    private var clusterCount: Int {
        switch kind {
        case .detail: 5
        case .sheet: 3
        case .tab:
            switch preset {
            case .today: 21
            case .train: 17
            case .wellness: 14
            case .life: 11
            }
        }
    }

    private var markCount: Int {
        switch kind {
        case .detail: 100
        case .sheet: 60
        case .tab:
            switch preset {
            case .today: 560
            case .train: 400
            case .wellness: 320
            case .life: 240
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Fill the background's proposed size so the short pond scene is
            // anchored to the top, like the other theme backgrounds.
            Color.clear

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

            if !reduceMotion && scenePhase == .active && kind == .tab {
                painting
                    .phaseAnimator([false, true]) { content, drifting in
                        content.offset(x: drifting ? 5 : -5)
                    } animation: { _ in
                        .easeInOut(duration: 20)
                    }
            } else {
                painting
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .ignoresSafeArea()
    }

    private var painting: some View {
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
        .mask {
            LinearGradient(
                colors: [.white, .white, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private enum WaterLiliesPainting {
    // Ordered to spread the first few clusters over the width for quieter presets.
    private static let placements: [(CGFloat, CGFloat, CGFloat, Bool)] = [
        (158, 43, 25, true), (275, 94, 33, false), (319, 146, 36, true),
        (91, 36, 23, false), (107, 86, 30, true), (281, 151, 34, false),
        (306, 41, 24, true), (178, 82, 26, false), (153, 149, 34, true),
        (339, 43, 20, false), (346, 98, 27, true), (116, 143, 33, false),
        (243, 30, 21, false), (73, 82, 28, false), (361, 153, 32, false),
        (124, 35, 27, false), (240, 97, 29, true), (192, 143, 31, false),
        (271, 36, 27, false), (141, 91, 29, false), (311, 102, 30, false)
    ]

    static func draw(in context: inout GraphicsContext, clusters: Int, marks: Int, strength: Double) {
        drawWater(in: &context, marks: marks, strength: strength)

        // Paint the distant islands first so nearby strokes overlap them.
        let visible = placements.prefix(clusters).sorted { $0.1 < $1.1 }
        for (x, y, size, hasFlower) in visible {
            let depth = y < 60 ? 0.56 : (y < 120 ? 0.78 : 1.0)
            drawLeaves(in: &context, x: x, y: y, size: size, strength: strength * depth)
            if hasFlower {
                drawFlower(in: &context, x: x + size * 0.15, y: y - size * 0.29, strength: strength * depth)
            }
        }
    }

    private static func drawWater(in context: inout GraphicsContext, marks: Int, strength: Double) {
        for index in 0..<marks {
            let seed = CGFloat(index)
            let x = (seed * 73.7).truncatingRemainder(dividingBy: 418) - 9
            let y = (seed * 43.3).truncatingRemainder(dividingBy: 195) + 8
            let radius = 0.7 + (seed * 1.37).truncatingRemainder(dividingBy: 2.1)
            let dab = Path(ellipseIn: CGRect(
                x: x, y: y, width: radius * (index.isMultiple(of: 5) ? 5 : 2), height: radius * 1.2
            ))
            let color = index.isMultiple(of: 4)
                ? WaterLiliesPalette.reflection
                : (index.isMultiple(of: 3) ? WaterLiliesPalette.waterDeep : WaterLiliesPalette.waterLight)
            context.fill(dab, with: .color(color.opacity((0.24 + Double(index % 5) * 0.08) * strength)))
        }

        for index in 0..<max(8, marks / 11) {
            let seed = CGFloat(index)
            let x = (seed * 67.3).truncatingRemainder(dividingBy: 400)
            let y = (seed * 29.7).truncatingRemainder(dividingBy: 175) + 8
            let length = 12 + (seed * 11.7).truncatingRemainder(dividingBy: 47)
            var stroke = Path()
            stroke.move(to: CGPoint(x: x, y: y))
            stroke.addQuadCurve(
                to: CGPoint(x: x + length, y: y - 0.7),
                control: CGPoint(x: x + length * 0.54, y: y - 2.3)
            )
            context.stroke(
                stroke,
                with: .color(WaterLiliesPalette.reflection.opacity(0.36 * strength)),
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
        for strokeIndex in 0..<15 {
            let offset = CGFloat(strokeIndex / 2 - 3)
            let jitter = sin(CGFloat(strokeIndex) * 2.7 + x * 0.11 + y * 0.07) * size * 0.035
            let row = y + offset * size * 0.105 + jitter
            let left = x - size * (0.65 + 0.29 * abs(sin(CGFloat(strokeIndex) * 1.9 + y * 0.03)))
            let right = x + size * (0.37 + 0.55 * abs(cos(CGFloat(strokeIndex) * 1.4 + x * 0.04)))
            let bend = CGFloat(strokeIndex % 3 - 1) * size * 0.065
            var leaf = Path()
            leaf.move(to: CGPoint(x: left, y: row))
            leaf.addQuadCurve(
                to: CGPoint(x: right, y: row + bend * 0.35),
                control: CGPoint(x: x + bend, y: row - 2.5 + jitter)
            )
            let color: Color
            switch strokeIndex % 3 {
            case 0: color = WaterLiliesPalette.leafDark
            case 1: color = WaterLiliesPalette.leafMid
            default: color = WaterLiliesPalette.leafLight
            }
            context.stroke(
                leaf,
                with: .color(color.opacity((0.28 + Double(strokeIndex % 4) * 0.10) * strength)),
                style: StrokeStyle(lineWidth: strokeIndex.isMultiple(of: 4) ? 5.2 : 2.9, lineCap: .round)
            )
        }
        for index in 0..<9 {
            let seed = CGFloat(index)
            let point = CGPoint(
                x: x + sin(seed * 2.32 + y) * size * 0.79,
                y: y + cos(seed * 3.17 + x) * size * 0.24
            )
            var fleck = Path()
            fleck.move(to: point)
            fleck.addLine(to: CGPoint(x: point.x + 2 + CGFloat(index % 4) * 1.5, y: point.y + CGFloat(index % 3 - 1)))
            context.stroke(fleck, with: .color(WaterLiliesPalette.reflection.opacity(0.5 * strength)),
                           style: StrokeStyle(lineWidth: 1 + CGFloat(index % 3) * 0.6, lineCap: .round))
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
