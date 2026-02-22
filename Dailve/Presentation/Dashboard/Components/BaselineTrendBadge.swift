import SwiftUI

struct BaselineTrendBadge: View {
    let detail: BaselineDetail
    let inversePolarity: Bool

    private var isNeutral: Bool {
        abs(detail.value) < 0.05
    }

    private var valueColor: Color {
        if isNeutral { return .secondary }
        let isPositive = detail.value > 0
        if inversePolarity {
            return isPositive ? DS.Color.negative : DS.Color.positive
        }
        return isPositive ? DS.Color.positive : DS.Color.negative
    }

    private var iconName: String {
        if isNeutral { return "minus" }
        return detail.value > 0 ? "arrow.up.right" : "arrow.down.right"
    }

    private var formattedDelta: String {
        abs(detail.value).formattedWithSeparator(fractionDigits: 1)
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(detail.label)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 2) {
                Image(systemName: iconName)
                    .font(.system(size: 9, weight: .bold))
                Text(formattedDelta)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .foregroundStyle(valueColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(valueColor.opacity(isNeutral ? 0.08 : 0.12), in: Capsule())
        }
    }
}
