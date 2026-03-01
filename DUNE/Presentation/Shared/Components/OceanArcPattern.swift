import SwiftUI

/// Japanese-style concentric arc pattern rendered between wave layers.
///
/// Draws groups of concentric semicircles (seigaiha-inspired) arranged
/// in a repeating grid. Each group has `ringsPerGroup` nested arcs
/// centered at evenly-spaced positions across the width.
struct OceanArcPattern: Shape {
    /// Number of arc groups across one row.
    let columns: Int
    /// Number of concentric rings per group.
    let ringsPerGroup: Int
    /// Vertical rows of arc groups.
    let rows: Int
    /// Horizontal offset in radians (0…2π). Animatable for slow drift.
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    init(
        columns: Int = 6,
        ringsPerGroup: Int = 3,
        rows: Int = 2,
        phase: CGFloat = 0
    ) {
        self.columns = Swift.max(columns, 1)
        self.ringsPerGroup = Swift.max(ringsPerGroup, 1)
        self.rows = Swift.max(rows, 1)
        self.phase = phase
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let colSpacing = rect.width / CGFloat(columns)
        let rowSpacing = rect.height / CGFloat(rows + 1)
        let baseRadius = colSpacing * 0.4
        let ringStep = baseRadius / CGFloat(ringsPerGroup)
        // Phase-based horizontal offset
        let phaseShift = (phase / (2 * .pi)) * colSpacing

        var path = Path()

        for row in 0..<rows {
            let centerY = rowSpacing * CGFloat(row + 1)
            // Offset even rows by half-column for brick pattern
            let rowOffset: CGFloat = row.isMultiple(of: 2) ? 0 : colSpacing * 0.5

            for col in -1...columns {
                let centerX = CGFloat(col) * colSpacing + colSpacing * 0.5
                    + rowOffset + phaseShift.truncatingRemainder(dividingBy: colSpacing)

                for ring in 1...ringsPerGroup {
                    let radius = ringStep * CGFloat(ring)
                    path.addArc(
                        center: CGPoint(x: centerX, y: centerY),
                        radius: radius,
                        startAngle: .degrees(180),
                        endAngle: .degrees(0),
                        clockwise: false
                    )
                }
            }
        }

        return path
    }
}

// MARK: - Animated Arc Overlay

/// Animated concentric arc pattern overlay for ocean backgrounds.
struct OceanArcOverlayView: View {
    var color: Color
    var opacity: Double = 0.1
    var lineWidth: CGFloat = 0.8
    var columns: Int = 6
    var ringsPerGroup: Int = 3
    var rows: Int = 2
    /// Duration of one full horizontal drift cycle (seconds).
    var driftDuration: TimeInterval = 20

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OceanArcPattern(
            columns: columns,
            ringsPerGroup: ringsPerGroup,
            rows: rows,
            phase: phase
        )
        .stroke(color.opacity(opacity), lineWidth: lineWidth)
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion, driftDuration > 0 else { return }
            withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                phase = 2 * .pi
            }
        }
    }
}
