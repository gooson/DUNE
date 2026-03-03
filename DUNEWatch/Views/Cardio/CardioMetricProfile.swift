import Foundation

/// Maps workout activity type to the metric set displayed on each page.
/// Used by CardioMainMetricsPage and CardioSecondaryPage to customize layout.
enum CardioMetricProfile: Sendable {
    case running
    case cycling
    case swimming
    case generic

    // MARK: - Factory

    static func profile(for activityType: WorkoutActivityType) -> CardioMetricProfile {
        switch activityType {
        case .running, .walking, .hiking, .stairClimbing, .stairStepper, .stepTraining:
            return .running
        case .cycling, .handCycling:
            return .cycling
        case .swimming:
            return .swimming
        case .elliptical, .rowing:
            return .running // Pace-based like running
        default:
            return .generic
        }
    }

    // MARK: - Page 1 (Main) Configuration

    /// Whether this profile shows a distance metric.
    var showsDistance: Bool {
        switch self {
        case .running, .cycling, .swimming: true
        case .generic: false
        }
    }

    /// Whether this profile shows pace (min/km).
    var showsPace: Bool {
        switch self {
        case .running, .swimming: true
        case .cycling, .generic: false
        }
    }

    /// Whether this profile shows speed (km/h).
    var showsSpeed: Bool {
        switch self {
        case .cycling: true
        case .running, .swimming, .generic: false
        }
    }

    /// Primary metric label for the main page.
    var primaryLabel: String {
        switch self {
        case .running, .swimming: String(localized: "Distance")
        case .cycling: String(localized: "Distance")
        case .generic: String(localized: "Elapsed")
        }
    }

    /// Secondary page title.
    var secondaryPageTitle: String {
        switch self {
        case .running: String(localized: "Pace")
        case .cycling: String(localized: "Speed")
        case .swimming: String(localized: "Swim")
        case .generic: String(localized: "Details")
        }
    }
}
