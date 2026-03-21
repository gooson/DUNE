import SwiftUI

struct HabitHeatmapView: View {
    let data: [DailyCompletionCount]
    let onTapDetail: () -> Void

    private let cellSpacing: CGFloat = 2
    private let rows = 7
    private let dayLabelWidth: CGFloat = 20
    private let dayLabelTrailingPadding: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            let cellSize = computeCellSize(for: geometry.size.width)

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                header

                Text("Daily habit completions over the last 90 days")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                heatmapGrid(cellSize: cellSize)

                legend(cellSize: cellSize)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: heatmapEstimatedHeight)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.ultraThinMaterial)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTapDetail() }
        .accessibilityIdentifier("habit-heatmap")
    }

    // MARK: - Layout Calculation

    private var columnCount: Int {
        let totalItems = paddedData.count
        return max(1, (totalItems + rows - 1) / rows)
    }

    private func computeCellSize(for totalWidth: CGFloat) -> CGFloat {
        let contentPadding = DS.Spacing.md * 2
        let availableWidth = totalWidth - contentPadding - dayLabelWidth - dayLabelTrailingPadding
        let cols = CGFloat(columnCount)
        let size = (availableWidth - (cols - 1) * cellSpacing) / cols
        return min(16, max(8, size))
    }

    private var heatmapEstimatedHeight: CGFloat {
        // header (~20) + description (~16) + spacing*3 + grid(7 cells + 6 spacings) + legend(~16) + padding*2
        let gridHeight: CGFloat = 7 * 12 + 6 * cellSpacing // approximate with size 12
        return 20 + 16 + DS.Spacing.md * 3 + gridHeight + 16 + DS.Spacing.md * 2
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

    // MARK: - Heatmap Grid

    private func heatmapGrid(cellSize: CGFloat) -> some View {
        let gridRows = Array(repeating: GridItem(.fixed(cellSize), spacing: cellSpacing), count: rows)

        return HStack(alignment: .top, spacing: 0) {
            dayLabels(cellSize: cellSize)

            LazyHGrid(rows: gridRows, spacing: cellSpacing) {
                ForEach(paddedData) { item in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(cellColor(for: item))
                        .frame(width: cellSize, height: cellSize)
                }
            }
        }
    }

    // MARK: - Padding & Color

    private var paddedData: [DailyCompletionCount] {
        guard let firstDate = data.first?.date else { return data }
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: firstDate)
        let mondayOffset = (weekday + 5) % 7
        let padding = (0..<mondayOffset).map { i in
            DailyCompletionCount(
                id: calendar.date(byAdding: .day, value: -(mondayOffset - i), to: firstDate) ?? firstDate,
                date: calendar.date(byAdding: .day, value: -(mondayOffset - i), to: firstDate) ?? firstDate,
                completionCount: -1
            )
        }
        return padding + data
    }

    private var maxCount: Int {
        max(1, data.map(\.completionCount).max() ?? 1)
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

    // MARK: - Day Labels

    private func dayLabels(cellSize: CGFloat) -> some View {
        VStack(spacing: cellSpacing) {
            ForEach(0..<rows, id: \.self) { row in
                Text(dayLabel(for: row))
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .frame(width: dayLabelWidth, height: cellSize, alignment: .trailing)
            }
        }
        .padding(.trailing, dayLabelTrailingPadding)
    }

    private func dayLabel(for row: Int) -> String {
        let labels = ["M", "", "W", "", "F", "", "S"]
        return labels[row]
    }

    // MARK: - Legend

    private func legend(cellSize: CGFloat) -> some View {
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
