import SwiftUI

/// Compact horizontal RPE picker for individual sets (6.0–10.0, 0.5 step).
struct SetRPEPickerView: View {
    @Binding var rpe: Double?

    private static let rpeColors: [Color] = [
        DS.Color.positive,     // 6.0
        DS.Color.positive,     // 6.5
        DS.Color.caution,      // 7.0
        DS.Color.caution,      // 7.5
        .orange,               // 8.0
        .orange,               // 8.5
        DS.Color.negative,     // 9.0
        DS.Color.negative,     // 9.5
        DS.Color.negative,     // 10.0
    ]

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            rpeHeader
            rpeButtons
        }
    }

    // MARK: - Header

    private var rpeHeader: some View {
        HStack {
            Text("RPE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

            Spacer()

            if let rpe {
                let level = RPELevel(value: rpe)
                Text("\(level.rir) reps left")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            if rpe != nil {
                Button {
                    withAnimation(DS.Animation.snappy) { self.rpe = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Buttons

    private var rpeButtons: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(Array(RPELevel.levels.enumerated()), id: \.offset) { index, level in
                rpeButton(level: level, color: Self.rpeColors[index])
            }
        }
    }

    private func rpeButton(level: Double, color: Color) -> some View {
        let isSelected = rpe == level

        return Button {
            withAnimation(DS.Animation.snappy) {
                rpe = level
            }
        } label: {
            Text(formatRPE(level))
                .font(.caption2.weight(isSelected ? .bold : .medium).monospacedDigit())
                .foregroundStyle(isSelected ? .white : DS.Color.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(isSelected ? color : color.opacity(DS.Opacity.light))
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private func formatRPE(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

#Preview("Set RPE Picker") {
    struct PreviewWrapper: View {
        @State private var rpe: Double? = 8.0

        var body: some View {
            VStack(spacing: DS.Spacing.xl) {
                SetRPEPickerView(rpe: $rpe)
                    .padding(.horizontal)

                if let rpe {
                    let level = RPELevel(value: rpe)
                    Text("\(level.displayLabel) — \(level.rir) RIR")
                        .font(.caption)
                } else {
                    Text("No RPE selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
