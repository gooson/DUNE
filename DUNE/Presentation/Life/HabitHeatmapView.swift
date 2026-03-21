import SwiftUI

struct HabitHeatmapView: View {
    let data: [DailyCompletionCount]
    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 2
    private let rows = 7

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Label {
                Text("Activity")
                    .font(.headline)
            } icon: {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundStyle(DS.Color.tabLife)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    dayLabels

                    LazyHGrid(rows: gridRows, spacing: cellSpacing) {
                        ForEach(paddedData) { item in
                            cellView(for: item)
                        }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            legend
        }
        .padding(DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.ultraThinMaterial)
        }
        .accessibilityIdentifier("habit-heatmap")
    }

    private var gridRows: [GridItem] {
        Array(repeating: GridItem(.fixed(cellSize), spacing: cellSpacing), count: rows)
    }

    /// Pad data to align with weekday grid (first cell = Monday)
    private var paddedData: [DailyCompletionCount] {
        guard let firstDate = data.first?.date else { return data }
        let calendar = Calendar.current
        // weekday: 1=Sunday..7=Saturday → Monday-aligned offset
        let weekday = calendar.component(.weekday, from: firstDate)
        let mondayOffset = (weekday + 5) % 7 // 0=Monday
        let padding = (0..<mondayOffset).map { i in
            DailyCompletionCount(
                id: calendar.date(byAdding: .day, value: -(mondayOffset - i), to: firstDate) ?? firstDate,
                date: calendar.date(byAdding: .day, value: -(mondayOffset - i), to: firstDate) ?? firstDate,
                completionCount: -1 // marker for empty
            )
        }
        return padding + data
    }

    private var maxCount: Int {
        max(1, data.map(\.completionCount).max() ?? 1)
    }

    private func cellView(for item: DailyCompletionCount) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(cellColor(for: item))
            .frame(width: cellSize, height: cellSize)
    }

    private func cellColor(for item: DailyCompletionCount) -> Color {
        if item.completionCount < 0 { return .clear }
        if item.completionCount == 0 {
            return DS.Color.tabLife.opacity(0.08)
        }
        let ratio = Double(item.completionCount) / Double(maxCount)
        let opacity = 0.2 + ratio * 0.8
        return DS.Color.tabLife.opacity(opacity)
    }

    private var dayLabels: some View {
        VStack(spacing: cellSpacing) {
            ForEach(0..<rows, id: \.self) { row in
                Text(dayLabel(for: row))
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: cellSize, alignment: .trailing)
            }
        }
        .padding(.trailing, 2)
    }

    private func dayLabel(for row: Int) -> String {
        // Mon, Tue, Wed, Thu, Fri, Sat, Sun
        let labels = ["M", "", "W", "", "F", "", "S"]
        return labels[row]
    }

    private var legend: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text("Less")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.Color.tabLife.opacity(0.08 + level * 0.8))
                    .frame(width: cellSize, height: cellSize)
            }

            Text("More")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
