import SwiftUI

extension WorkoutIntensityLevel {
    var displayName: String {
        switch self {
        case .veryLight: "Very Light"
        case .light: "Light"
        case .moderate: "Moderate"
        case .hard: "Hard"
        case .maxEffort: "Max Effort"
        }
    }

    var iconName: String {
        switch self {
        case .veryLight: "flame"
        case .light: "flame"
        case .moderate: "flame.fill"
        case .hard: "flame.fill"
        case .maxEffort: "flame.fill"
        }
    }

    var color: Color {
        switch self {
        case .veryLight: DS.Color.positive
        case .light: DS.Color.positive
        case .moderate: DS.Color.warning
        case .hard: DS.Color.activity
        case .maxEffort: DS.Color.negative
        }
    }
}
