import SwiftUI

extension WorkoutIntensityLevel {
    var displayName: String {
        switch self {
        case .veryLight: String(localized: "Very Light")
        case .light: String(localized: "Light")
        case .moderate: String(localized: "Moderate")
        case .hard: String(localized: "Hard")
        case .maxEffort: String(localized: "Max Effort")
        }
    }

    var iconName: String {
        self <= .light ? "flame" : "flame.fill"
    }

    var color: Color {
        switch self {
        case .veryLight, .light: DS.Color.positive
        case .moderate: DS.Color.caution
        case .hard: DS.Color.activity
        case .maxEffort: DS.Color.negative
        }
    }
}

// MARK: - Effort Category UI

extension EffortCategory {
    var displayName: String {
        switch self {
        case .easy: String(localized: "Easy")
        case .moderate: String(localized: "Moderate")
        case .hard: String(localized: "Hard")
        case .allOut: String(localized: "All Out")
        }
    }

    var color: Color {
        switch self {
        case .easy: DS.Color.positive
        case .moderate: DS.Color.caution
        case .hard: .orange
        case .allOut: DS.Color.negative
        }
    }

    var iconName: String {
        self >= .hard ? "flame.fill" : "flame"
    }
}
