import SwiftUI

/// Dailve Design System — single source of truth for all visual tokens.
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
