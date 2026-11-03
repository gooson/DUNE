import SwiftUI

/// Reusable change indicator badge showing percentage change with arrow.
struct ChangeBadge: View {
    let change: Double?
    var showNoData: Bool = false
    var foregroundColor: Color? = nil

    var body: some View {
        if let change {
            let isPositive = change >= 0
            HStack(spacing: 2) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                Text("\(abs(change).formattedWithSeparator())%")
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
            }
            .foregroundStyle(foregroundColor ?? (isPositive ? DS.Color.positive : DS.Color.negative))
        } else if showNoData {
            Text("— No previous data")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
