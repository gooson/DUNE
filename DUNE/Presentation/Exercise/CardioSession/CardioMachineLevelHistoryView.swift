import SwiftUI

/// Ordered machine level selections at active workout times.
struct CardioMachineLevelHistoryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let changes: [CardioMachineLevelChange]

    var body: some View {
        if !changes.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label("Level History", systemImage: "chart.xyaxis.line")
                    .font(.headline)

                ForEach(changes.indices, id: \.self) { index in
                    let change = changes[index]
                    let rowLayout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
                        : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
                    rowLayout {
                        Text(change.formattedElapsed)
                            .monospacedDigit()
                            .foregroundStyle(DS.Color.textSecondary)
                        if !dynamicTypeSize.isAccessibilitySize {
                            Spacer(minLength: DS.Spacing.sm)
                        }
                        Text("Level")
                        Text(change.level.formatted())
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                    .padding(.vertical, DS.Spacing.xs)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        Text("Elapsed Time") + Text(verbatim: ": \(change.formattedElapsed), ")
                        + Text("Level") + Text(verbatim: " \(change.level)")
                    )
                    .accessibilityIdentifier("cardio-level-history-row-\(index)")
                }
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .accessibilityIdentifier("cardio-level-history")
        }
    }
}

#Preview {
    CardioMachineLevelHistoryView(changes: [
        CardioMachineLevelChange(elapsedSeconds: 0, level: 5)!,
        CardioMachineLevelChange(elapsedSeconds: 270, level: 7)!
    ])
}
