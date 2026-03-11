import SwiftUI
import WatchKit

/// Compact 3×3 grid RPE picker for watchOS (Modified Borg scale 6.0–10.0, 0.5 step).
struct WatchSetRPEPickerView: View {
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

    private let columns = Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.xs), count: 3)

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            rpeHeader
            rpeGrid
        }
    }

    // MARK: - Header

    private var rpeHeader: some View {
        HStack {
            Text("RPE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

            Spacer()

            if let rpe {
                let level = RPELevel(value: rpe)
                Text(level.displayLabel)
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            if rpe != nil {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { self.rpe = nil }
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Grid

    private var rpeGrid: some View {
        LazyVGrid(columns: columns, spacing: DS.Spacing.xs) {
            ForEach(Array(RPELevel.levels.enumerated()), id: \.offset) { index, level in
                rpeButton(level: level, color: Self.rpeColors[index])
            }
        }
    }

    private func rpeButton(level: Double, color: Color) -> some View {
        let isSelected = rpe == level

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                rpe = isSelected ? nil : level
            }
            WKInterfaceDevice.current().play(.click)
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
    }

    private func formatRPE(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

#Preview("Watch RPE Picker") {
    struct PreviewWrapper: View {
        @State private var rpe: Double? = 8.0

        var body: some View {
            ScrollView {
                WatchSetRPEPickerView(rpe: $rpe)
                    .padding(.horizontal)

                if let rpe {
                    Text("\(RPELevel(value: rpe).displayLabel)")
                        .font(.caption2)
                } else {
                    Text("No RPE")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    return PreviewWrapper()
}
