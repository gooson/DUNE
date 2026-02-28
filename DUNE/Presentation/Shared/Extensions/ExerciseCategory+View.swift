import SwiftUI

extension SetType {
    var displayName: String {
        switch self {
        case .warmup: "Warmup"
        case .working: "Working"
        case .drop: "Drop Set"
        case .failure: "Failure"
        case .interval: "Interval"
        case .rest: "Rest"
        }
    }

    var iconName: String {
        switch self {
        case .warmup: "flame"
        case .working: "dumbbell.fill"
        case .drop: "arrow.down.circle"
        case .failure: "exclamationmark.triangle"
        case .interval: "timer"
        case .rest: "pause.circle"
        }
    }

    var tintColor: Color {
        switch self {
        case .warmup: .orange
        case .working: DS.Color.activity
        case .drop: .purple
        case .failure: .red
        case .interval: DS.Color.activity
        case .rest: .secondary
        }
    }

    var shortLabel: String {
        switch self {
        case .warmup: "W"
        case .working: "S"
        case .drop: "D"
        case .failure: "F"
        case .interval: "I"
        case .rest: "R"
        }
    }
}
