import SwiftUI

extension InjurySeverity {
    var displayName: String {
        switch self {
        case .minor: "Minor"
        case .moderate: "Moderate"
        case .severe: "Severe"
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .minor: "경미"
        case .moderate: "보통"
        case .severe: "심각"
        }
    }

    var color: Color {
        switch self {
        case .minor: .yellow
        case .moderate: .orange
        case .severe: .red
        }
    }

    var iconName: String {
        switch self {
        case .minor: "exclamationmark.circle"
        case .moderate: "exclamationmark.triangle"
        case .severe: "xmark.octagon.fill"
        }
    }

    var bilingualDisplayName: String {
        switch self {
        case .minor: "경미 (Minor)"
        case .moderate: "보통 (Moderate)"
        case .severe: "심각 (Severe)"
        }
    }

    var localizedSeverityDescription: String {
        switch self {
        case .minor: "주의하며 운동 가능"
        case .moderate: "해당 부위 운동 회피 권장"
        case .severe: "해당 부위 운동 금지"
        }
    }
}
