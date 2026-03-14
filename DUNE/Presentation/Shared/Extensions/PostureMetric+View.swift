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

    var description: String {
        switch self {
        case .forwardHead:
            String(localized: "Head position relative to the shoulder line. Forward head posture increases neck strain.")
        case .roundedShoulders:
            String(localized: "Shoulder position relative to the spine. Rounded shoulders indicate tight chest muscles.")
        case .thoracicKyphosis:
            String(localized: "Upper back curvature. Excessive kyphosis can lead to back pain and breathing issues.")
        case .kneeHyperextension:
            String(localized: "Knee extension angle. Hyperextension puts stress on knee ligaments.")
        case .shoulderAsymmetry:
            String(localized: "Height difference between shoulders. May indicate muscular imbalance or scoliosis.")
        case .hipAsymmetry:
            String(localized: "Height difference between hips. Can affect gait and cause lower back pain.")
        case .kneeAlignment:
            String(localized: "Knee angle in the frontal plane. Valgus or varus alignment affects joint loading.")
        case .lateralShift:
            String(localized: "Horizontal offset of the head from the body center. Indicates weight distribution imbalance.")
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
