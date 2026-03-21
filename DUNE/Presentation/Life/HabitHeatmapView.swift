import SwiftUI

struct HabitHeatmapView: View {
    let data: [DailyCompletionCount]
    let onTapDetail: () -> Void

    var body: some View {
        Button(action: onTapDetail) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                header

                Text("Daily habit completions over the last 90 days")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HabitHeatmapGridView(data: data)

                HabitHeatmapLegend()
            }
            .padding(DS.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(.ultraThinMaterial)
            }
        }
        .buttonStyle(CardPressButtonStyle())
        .accessibilityIdentifier("habit-heatmap")
        .accessibilityLabel(Text("Activity heatmap"))
        .accessibilityHint(Text("Tap to view detail"))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label {
                Text("Activity")
                    .font(.headline)
            } icon: {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundStyle(DS.Color.tabLife)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Card Press Button Style

private struct CardPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
