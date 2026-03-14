import SwiftUI

extension PostureMetricType {
    var displayName: String {
        switch self {
        case .forwardHead: String(localized: "Forward Head")
        case .roundedShoulders: String(localized: "Rounded Shoulders")
        case .thoracicKyphosis: String(localized: "Thoracic Kyphosis")
        case .kneeHyperextension: String(localized: "Knee Hyperextension")
        case .shoulderAsymmetry: String(localized: "Shoulder Asymmetry")
        case .hipAsymmetry: String(localized: "Hip Asymmetry")
        case .kneeAlignment: String(localized: "Knee Alignment")
        case .lateralShift: String(localized: "Lateral Shift")
        }
    }

    var iconName: String {
        switch self {
        case .forwardHead: "person.crop.circle"
        case .roundedShoulders: "figure.arms.open"
        case .thoracicKyphosis: "figure.stand"
        case .kneeHyperextension: "figure.walk"
        case .shoulderAsymmetry: "arrow.left.arrow.right"
        case .hipAsymmetry: "arrow.up.arrow.down"
        case .kneeAlignment: "arrow.triangle.branch"
        case .lateralShift: "arrow.left.and.right"
        }
    }

}

extension PostureStatus {
    var color: Color {
        switch self {
        case .normal: .green
        case .caution: .yellow
        case .warning: .red
        case .unmeasurable: .gray
        }
    }

    var displayName: String {
        switch self {
        case .normal: String(localized: "Normal")
        case .caution: String(localized: "Caution")
        case .warning: String(localized: "Warning")
        case .unmeasurable: String(localized: "Unmeasurable")
        }
    }

    var iconName: String {
        switch self {
        case .normal: "checkmark.circle.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .warning: "xmark.circle.fill"
        case .unmeasurable: "questionmark.circle.fill"
        }
    }
}
