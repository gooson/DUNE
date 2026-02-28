import SwiftUI

/// Shared row component used by ConditionCalculationCard and BodyCalculationCard.
struct CalculationRow: View {
    let label: String
    let value: String
    let sub: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()

                if !sub.isEmpty {
                    Text(sub)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
