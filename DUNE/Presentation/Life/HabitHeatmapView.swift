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
        .buttonStyle(CardNavigationButtonStyle())
        .accessibilityIdentifier("habit-heatmap")
        .accessibilityLabel(Text("Activity heatmap"))
        .accessibilityHint(Text("Tap to view detail"))
    }

    // MARK: - Header

    private var header: some View {
        CardNavigationHeader(minimumHeight: 0) {
            Label {
                Text("Activity")
                    .font(.headline)
            } icon: {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundStyle(DS.Color.tabLife)
            }
        }
    }
}
