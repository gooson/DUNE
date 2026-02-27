import SwiftUI

/// DUNE Design System — single source of truth for all visual tokens.
enum DS {
    // MARK: - Color

    enum Color {
        // Score gradient (5 levels)
        static let scoreExcellent = SwiftUI.Color("ScoreExcellent")
        static let scoreGood      = SwiftUI.Color("ScoreGood")
        static let scoreFair      = SwiftUI.Color("ScoreFair")
        static let scoreTired     = SwiftUI.Color("ScoreTired")
        static let scoreWarning   = SwiftUI.Color("ScoreWarning")

        // Metric category (distinguishable when shown together)
        static let hrv       = SwiftUI.Color("MetricHRV")
        static let rhr       = SwiftUI.Color("MetricRHR")
        static let heartRate = SwiftUI.Color("MetricHeartRate")
        static let sleep     = SwiftUI.Color("MetricSleep")
        static let activity  = SwiftUI.Color("MetricActivity")
        static let steps     = SwiftUI.Color("MetricSteps")
        static let body      = SwiftUI.Color("MetricBody")
        static let vitals    = SwiftUI.Color("WellnessVitals")
        static let fitness   = SwiftUI.Color("WellnessFitness")

        // Heart Rate Zones (5 levels)
        static let zone1 = SwiftUI.Color("HRZone1")
        static let zone2 = SwiftUI.Color("HRZone2")
        static let zone3 = SwiftUI.Color("HRZone3")
        static let zone4 = SwiftUI.Color("HRZone4")
        static let zone5 = SwiftUI.Color("HRZone5")

        // Wellness Score gradient (4 levels)
        static let wellnessExcellent = SwiftUI.Color("WellnessScoreExcellent")
        static let wellnessGood      = SwiftUI.Color("WellnessScoreGood")
        static let wellnessFair      = SwiftUI.Color("WellnessScoreFair")
        static let wellnessWarning   = SwiftUI.Color("WellnessScoreWarning")

        // Feedback
        static let positive = SwiftUI.Color("Positive")
        static let negative = SwiftUI.Color("Negative")
        static let caution  = SwiftUI.Color("Caution")

        // Surface
        static let cardBackground = SwiftUI.Color("CardBackground")
        static let surfacePrimary = SwiftUI.Color("SurfacePrimary")

        // Warm glow (derived from AccentColor for icon-aligned highlights)
        static let warmGlow = SwiftUI.Color("AccentColor")

        // Desert Palette — extracted from Desert Horizon ring gradient
        static let desertDusk   = SwiftUI.Color("DesertDusk")    // Cool blue-gray (ring bottom)
        static let desertBronze = SwiftUI.Color("DesertBronze")  // Copper/bronze (ring number)
        static let sandMuted    = SwiftUI.Color("SandMuted")     // Muted sand (decorative text)

        // Activity Category Colors — Desert Horizon Chart Palette
        static let activityCardio    = SwiftUI.Color(red: 0.92, green: 0.75, blue: 0.35) // Desert Gold
        static let activityStrength  = SwiftUI.Color(red: 0.88, green: 0.58, blue: 0.36) // Copper
        static let activityMindBody  = SwiftUI.Color(red: 0.74, green: 0.60, blue: 0.80) // Dusk Lavender
        static let activityDance     = SwiftUI.Color(red: 0.85, green: 0.54, blue: 0.58) // Desert Rose
        static let activityCombat    = SwiftUI.Color(red: 0.82, green: 0.46, blue: 0.36) // Terracotta
        static let activitySports    = SwiftUI.Color(red: 0.58, green: 0.66, blue: 0.82) // Dusk Slate
        static let activityWater     = SwiftUI.Color(red: 0.48, green: 0.72, blue: 0.68) // Oasis Teal
        static let activityWinter    = SwiftUI.Color(red: 0.60, green: 0.54, blue: 0.76) // Twilight
        static let activityOutdoor   = SwiftUI.Color(red: 0.62, green: 0.74, blue: 0.50) // Desert Sage
        static let activityOther     = SwiftUI.Color(red: 0.64, green: 0.60, blue: 0.54) // Warm Stone

        // Tab wave identity — Desert Horizon palette
        static let tabTrain    = SwiftUI.Color("TabTrain")     // Desert Coral
        static let tabWellness = SwiftUI.Color("TabWellness")  // Oasis Teal
    }

    // MARK: - Opacity

    enum Opacity {
        /// Background wave decorations, empty-state fills (0.06)
        static let subtle: Double = 0.06
        /// Card shadow, badge background tint (0.08)
        static let light: Double = 0.08
        /// Tab background gradient mid-stop (0.10)
        static let medium: Double = 0.10
        /// Card border in dark mode (0.15)
        static let border: Double = 0.15
        /// Hero card border highlight (0.30)
        static let strong: Double = 0.30
    }

    // MARK: - Gradient

    enum Gradient {
        /// Tab background gradient fade-out point (slightly below center)
        static let tabBackgroundEnd = UnitPoint(x: 0.5, y: 0.6)
        /// Sheet/modal gradient fade-out point (center)
        static let sheetBackgroundEnd = UnitPoint(x: 0.5, y: 0.5)

        // Hero card ring gradient direction
        static let heroRingStart = UnitPoint(x: 0, y: 0)
        static let heroRingEnd = UnitPoint(x: 1, y: 1)
    }

    // MARK: - Spacing (4pt grid)

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    // MARK: - Animation

    enum Animation {
        /// Quick snap (toggles, small state changes)
        static let snappy = SwiftUI.Animation.spring(duration: 0.25, bounce: 0.05)
        /// Standard interaction (cards, transitions)
        static let standard = SwiftUI.Animation.spring(duration: 0.35, bounce: 0.1)
        /// Emphasize (hero elements, large movements)
        static let emphasize = SwiftUI.Animation.spring(duration: 0.6, bounce: 0.15)
        /// Slow entrance (score ring fill)
        static let slow = SwiftUI.Animation.spring(duration: 1.0, bounce: 0.1)
        /// Numeric value changes (score counters)
        static let numeric = SwiftUI.Animation.easeOut(duration: 0.6)
        /// Subtle wave drift (background decoration)
        static let waveDrift = SwiftUI.Animation.linear(duration: 6).repeatForever(autoreverses: false)
        /// Sand shimmer flash (period transition overlay)
        static let shimmer = SwiftUI.Animation.easeInOut(duration: 0.4)
    }

    // MARK: - Typography (Dynamic Type compatible)

    enum Typography {
        /// Large score display (detail views). Scales with Dynamic Type via .largeTitle base.
        static let heroScore = Font.system(.largeTitle, design: .rounded, weight: .bold)
        /// Card-level score display (hero card, summary header). Scales with Dynamic Type via .title base.
        static let cardScore = Font.system(.title, design: .rounded, weight: .bold)
        /// Section headers.
        static let sectionTitle = Font.title3.weight(.semibold)
    }
}
