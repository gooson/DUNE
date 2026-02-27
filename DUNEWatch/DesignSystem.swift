import SwiftUI

/// Watch Design System — lightweight token set mirroring iOS DS.
/// Colors reference named assets in DUNEWatch/Resources/Assets.xcassets/Colors/.
/// TODO: Consolidate with iOS DS via shared Swift package to enforce single source of truth.
enum DS {
    // MARK: - Color

    enum Color {
        // Feedback
        static let positive = SwiftUI.Color("Positive")
        static let negative = SwiftUI.Color("Negative")
        static let caution  = SwiftUI.Color("Caution")

        // Warm glow (derived from AccentColor)
        static let warmGlow = SwiftUI.Color("AccentColor")

        // Metric category
        static let hrv       = SwiftUI.Color("MetricHRV")
        static let rhr       = SwiftUI.Color("MetricRHR")
        static let heartRate = SwiftUI.Color("MetricHeartRate")
        static let sleep     = SwiftUI.Color("MetricSleep")
        static let activity  = SwiftUI.Color("MetricActivity")
        static let steps     = SwiftUI.Color("MetricSteps")
        static let body      = SwiftUI.Color("MetricBody")
        static let vitals    = SwiftUI.Color("WellnessVitals")
        static let fitness   = SwiftUI.Color("WellnessFitness")

        // Surface
        // cardBackground intentionally omitted — watchOS uses system material backgrounds
        static let surfacePrimary = SwiftUI.Color("SurfacePrimary")

        // Desert Palette — extracted from Desert Horizon ring gradient (mirrors iOS DS)
        static let desertDusk   = SwiftUI.Color("DesertDusk")    // Cool blue-gray (ring bottom)
        static let desertBronze = SwiftUI.Color("DesertBronze")  // Copper/bronze (ring number)
        static let sandMuted    = SwiftUI.Color("SandMuted")     // Muted sand (decorative text)

        // Tab wave identity — Desert Horizon palette (mirrors iOS DS)
        static let tabTrain    = SwiftUI.Color("TabTrain")     // Desert Coral
        static let tabWellness = SwiftUI.Color("TabWellness")  // Oasis Teal
    }

    // MARK: - Opacity (mirrors iOS DS.Opacity)

    enum Opacity {
        static let subtle: Double = 0.06
        static let light: Double = 0.08
        static let medium: Double = 0.10
        static let border: Double = 0.15
        static let strong: Double = 0.30
    }

    // MARK: - Spacing (Watch-adapted 4pt grid — tighter than iOS)

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6   // iOS: 8 — Watch screens are narrower
        static let md: CGFloat = 8   // iOS: 12
        static let lg: CGFloat = 12  // iOS: 16
        static let xl: CGFloat = 16  // iOS: 20
    }

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 18  // watchOS standard card radius
    }

    // MARK: - Typography

    enum Typography {
        /// Exercise name in tile / metrics header
        static let exerciseName = Font.headline.bold()
        /// Large metric value (weight, timer countdown)
        static let metricValue = Font.system(.title2, design: .rounded).monospacedDigit().bold()
        /// Metric label / caption
        static let metricLabel = Font.caption2.weight(.medium)
        /// Tile primary text (exercise name in list)
        static let tileTitle = Font.system(.body, design: .rounded).weight(.semibold)
        /// Tile secondary text (sets × reps · weight)
        static let tileSubtitle = Font.caption.weight(.medium)
        /// Section header
        static let sectionTitle = Font.headline.weight(.semibold)
    }

    // MARK: - Animation

    enum Animation {
        /// Slow, infinite drift for wave background decoration.
        static let waveDrift: SwiftUI.Animation = .linear(duration: 8).repeatForever(autoreverses: false)
        /// Standard interaction (card tap, state change)
        static let standard: SwiftUI.Animation = .spring(duration: 0.25, bounce: 0.05)
        /// Numeric value transition (weight, reps, timer)
        static let numeric: SwiftUI.Animation = .easeOut(duration: 0.3)
    }

    // MARK: - Gradient

    enum Gradient {
        /// Warm card background (top-leading warm glow fade)
        static func cardBackground(color: SwiftUI.Color = DS.Color.warmGlow) -> LinearGradient {
            LinearGradient(
                colors: [color.opacity(DS.Opacity.subtle), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
