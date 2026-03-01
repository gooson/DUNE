import SwiftUI

/// Mountain/forest silhouette Shape for the Forest Green theme.
///
/// Generates a ridge-line profile using:
/// - Multi-frequency sinusoidal harmonics for organic mountain contours
/// - Triangle-wave pine canopy clusters for tree silhouettes
/// - Catmull-Rom → cubic Bezier spline for smooth curves
///
/// Uses shared `WaveSamples` for point pre-computation.
struct ForestSilhouetteShape: Shape {
    /// Mountain height as a fraction of the rect height (0…1).
    let amplitude: CGFloat
    /// Number of full ridge periods across the rect width.
    let frequency: CGFloat
    /// Phase offset in radians (0…2π). Animatable for drift effect.
    var phase: CGFloat
    /// Vertical center of the ridge as a fraction of the rect height (0…1).
    let verticalOffset: CGFloat
    /// Tree silhouette density on ridge line (0 = none, 1 = dense).
    let treeDensity: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private let samples: WaveSamples

    init(
        amplitude: CGFloat = 0.05,
        frequency: CGFloat = 1.5,
        phase: CGFloat = 0,
        verticalOffset: CGFloat = 0.5,
        treeDensity: CGFloat = 0
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.treeDensity = treeDensity
        self.samples = WaveSamples(frequency: frequency)
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset
        let pts = samples.points

        // Compute all Y values
        var yValues = [CGFloat]()
        yValues.reserveCapacity(pts.count)
        for pt in pts {
            let angle = pt.angle + phase
            var y = ridgeY(angle: angle)
            if treeDensity > 0 {
                y += treeDensity * Self.pineCanopy(angle: angle)
            }
            yValues.append(centerY + amp * y)
        }

        // Build smooth Bezier path from computed points
        var path = Path()
        let points = zip(pts, yValues).map { CGPoint(x: $0.x * rect.width, y: $1) }

        guard points.count >= 2 else { return Path() }

        path.move(to: points[0])

        // Catmull-Rom to cubic Bezier conversion for smooth curves
        for i in 0..<(points.count - 1) {
            let p0 = points[Swift.max(0, i - 1)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[Swift.min(points.count - 1, i + 2)]

            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6,
                y: p1.y + (p2.y - p0.y) / 6
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6,
                y: p2.y - (p3.y - p1.y) / 6
            )

            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }

        // Close area to bottom of rect for fill
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }

    // MARK: - Ridge Harmonics

    /// Multi-frequency mountain ridge profile.
    /// Combines primary peaks with secondary hills and subtle tertiary undulation.
    @inline(__always)
    private func ridgeY(angle: CGFloat) -> CGFloat {
        // Primary ridge: large mountain peaks
        let primary = sin(angle)

        // Secondary hills: medium undulations between peaks
        let secondary = 0.35 * sin(2.3 * angle + 0.7)

        // Tertiary undulation: gentle organic variation
        let tertiary = 0.15 * sin(4.7 * angle + 1.4)

        return primary + secondary + tertiary
    }

    // MARK: - Pine Tree Silhouette

    /// Composite pine canopy profile using multi-frequency triangle waves.
    /// Produces pointed tree-top silhouettes at varying scales.
    private static func pineCanopy(angle: CGFloat) -> CGFloat {
        // Large pines (widely spaced)
        let large = triangleWave(angle * 3.1 + 0.5) * 0.45

        // Medium pines (intermediate spacing)
        let medium = triangleWave(angle * 5.7 + 1.2) * 0.32

        // Small pines (dense undergrowth)
        let small = triangleWave(angle * 8.3 + 2.8) * 0.23

        // Negative = upward (toward top of screen)
        return -(large + medium + small)
    }

    /// Asymmetric triangle wave producing pointed peaks like pine tree tips.
    /// Rise is steeper than fall, mimicking conifer silhouette profile.
    /// Output range: 0…1
    @inline(__always)
    private static func triangleWave(_ x: CGFloat) -> CGFloat {
        let t = x / (2 * .pi)
        let frac = t - floor(t)
        if frac < 0.35 {
            // Steep rise (windward side of tree)
            return frac / 0.35
        } else {
            // Gradual descent (leeward branches)
            return (1 - frac) / 0.65
        }
    }
}
