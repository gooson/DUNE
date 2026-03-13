import SwiftUI

/// Compact delta badge showing score change direction and magnitude.
/// Used on hero cards to show hourly score changes.
struct ScoreDeltaBadge: View {
    let delta: Double
    let direction: DeltaDirection

    private enum Layout {
        static let fontSize: CGFloat = 11
        static let iconSize: CGFloat = 8
        static let horizontalPadding: CGFloat = 6
        static let verticalPadding: CGFloat = 2
    }

    private var icon: String {
        switch direction {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .stable: "minus"
        }
    }

    private var tintColor: Color {
        switch direction {
        case .up: DS.Color.positive
        case .down: DS.Color.negative
        case .stable: DS.Color.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: Layout.iconSize, weight: .bold))

            if direction != .stable {
                Text("\(Int(abs(delta)))")
                    .font(.system(size: Layout.fontSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(tintColor)
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .background(
            Capsule()
                .fill(tintColor.opacity(0.12))
        )
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let magnitude = Int(abs(delta))
        switch direction {
        case .up: return String(localized: "Up \(magnitude) points")
        case .down: return String(localized: "Down \(magnitude) points")
        case .stable: return String(localized: "Stable")
        }
    }
}
