import SwiftUI

extension SetType {
    var displayName: String {
        switch self {
        case .warmup: String(localized: "Warmup")
        case .working: String(localized: "Working")
        case .drop: String(localized: "Drop Set")
        case .failure: String(localized: "Failure")
        }
    }

    var iconName: String {
        switch self {
        case .warmup: "flame"
        case .working: "dumbbell.fill"
        case .drop: "arrow.down.circle"
        case .failure: "exclamationmark.triangle"
        }
    }

    var tintColor: Color {
        switch self {
        case .warmup: .orange
        case .working: DS.Color.activity
        case .drop: .purple
        case .failure: .red
        }
    }

    var shortLabel: String {
        switch self {
        case .warmup: "W"
        case .working: "S"
        case .drop: "D"
        case .failure: "F"
        }
    }
}
