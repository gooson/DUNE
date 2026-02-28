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
        self <= .light ? "flame" : "flame.fill"
    }

    var color: Color {
        switch self {
        case .veryLight, .light: DS.Color.positive
        case .moderate: DS.Color.warning
        case .hard: DS.Color.activity
        case .maxEffort: DS.Color.negative
        }
    }
}
