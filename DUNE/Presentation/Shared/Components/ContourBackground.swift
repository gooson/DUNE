import SwiftUI

/// Shared by iOS and watchOS. These contours are decorative, never health-data traces.
enum ContourPalette {
    static let background = Color("ContourBackground")
    static let ink = Color("ContourInk")
    static let accent = Color("ContourAccent")
    static let surface = Color("ContourCardBackground")
}

/// Cached unit-space geometry keeps trigonometry out of Shape.path(in:).
struct ContourLines: Shape {
    var simplified = false

    private static let rings: [[CGPoint]] = (0..<14).map { ring in
        let radius = 0.12 + Double(ring) * 0.045
        return (0..<96).map { sample in
            let angle = Double(sample) / 96 * 2 * .pi
            let relief = 1 + 0.12 * sin(angle * 3) + 0.06 * cos(angle * 5)
            return CGPoint(
                x: cos(angle) * radius * relief,
                y: sin(angle) * radius * relief * 0.72
            )
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scale = min(rect.width, rect.height * 1.8)
        for (index, ring) in Self.rings.enumerated() {
            if simplified && !index.isMultiple(of: 2) { continue }
            let points = ring.map {
                CGPoint(x: rect.minX + rect.width * 0.94 + $0.x * scale,
                        y: rect.minY + rect.height * 0.12 + $0.y * scale)
            }
            path.addLines(points)
            path.closeSubpath()
        }
        return path
    }
}

/// A quiet topographic field with an opaque base and a clear reading area.
/// Animates cached contours using transforms, preserving a calm reading area.
struct ContourBackground: View {
    #if os(watchOS)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #else
    @Environment(\.waveReducedMotion) private var reduceMotion
    #endif
    @Environment(\.scenePhase) private var scenePhase

    enum Style {
        case tab, detail, sheet, watch

        var lineOpacity: Double {
            switch self {
            case .tab: 0.18
            case .detail: 0.12
            case .sheet: 0.09
            case .watch: 0.16
            }
        }
    }

    var style: Style = .tab

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ContourPalette.background

                if !reduceMotion && scenePhase == .active && style != .watch {
                    contourField
                        .phaseAnimator([false, true]) { content, expanded in
                            content
                                .scaleEffect(expanded ? 1.06 : 1, anchor: .topTrailing)
                                .rotationEffect(.degrees(expanded ? 3 : 0), anchor: .topTrailing)
                                .offset(x: expanded ? -10 : 0, y: expanded ? 12 : 0)
                        } animation: { _ in
                            .easeInOut(duration: 8)
                        }
                        .transition(.opacity)
                } else {
                    contourField
                        .transition(.opacity)
                }

                // Small cartographic reference mark at the edge of the field.
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .light))
                    .foregroundStyle(ContourPalette.accent)
                    .position(x: geometry.size.width * 0.91, y: geometry.size.height * 0.24)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: scenePhase)
        }
        .clipped()
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var contourField: some View {
        ZStack {
            ContourLines(simplified: style == .watch)
                .stroke(ContourPalette.ink.opacity(style.lineOpacity), lineWidth: 0.7)

            if style == .tab {
                if !reduceMotion && scenePhase == .active {
                    secondaryContours
                        .phaseAnimator([false, true]) { content, expanded in
                            content
                                .rotationEffect(.degrees(expanded ? -5 : 0), anchor: .bottomLeading)
                                .offset(x: expanded ? 12 : 0, y: expanded ? -8 : 0)
                        } animation: { _ in
                            .easeInOut(duration: 11)
                        }
                } else {
                    secondaryContours
                }
            }
        }
    }

    private var secondaryContours: some View {
        ContourLines(simplified: true)
            .stroke(ContourPalette.ink.opacity(0.08), lineWidth: 0.7)
            .rotationEffect(.degrees(180))
    }
}

#Preview("Contour Light") {
    ContourBackground()
        .preferredColorScheme(.light)
}

#Preview("Contour Dark") {
    ContourBackground()
        .preferredColorScheme(.dark)
}
