import SwiftUI

/// Watch Design System — lightweight token set mirroring iOS DS.
/// Colors reference named assets in DUNEWatch/Resources/Assets.xcassets/Colors/.
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
        static let surfacePrimary = SwiftUI.Color("SurfacePrimary")
    }
}
