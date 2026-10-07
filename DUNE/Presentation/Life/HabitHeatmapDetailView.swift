import SwiftUI

struct HabitHeatmapDetailView: View {
    let data: [DailyCompletionCount]

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                summaryCard
                statsRow
                heatmapCard
                weekdayBreakdownCard
            }
            .padding(DS.Spacing.md)
        }
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Activity Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("Last 90 Days")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(totalCompletions)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(DS.Color.tabLife)

            Text("Total Completions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.xl)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: DS.Spacing.md) {
            statCard(
                title: "Daily Average",
                value: dailyAverage.formatted(.number.precision(.fractionLength(1))),
                icon: "chart.line.uptrend.xyaxis"
            )

            statCard(
                title: "Longest Streak",
                value: "\(longestStreak)",
                icon: "flame.fill"
            )

            statCard(
                title: "Active Days",
                value: "\(activeDays)",
                icon: "checkmark.circle.fill"
            )
        }
    }

    private func statCard(title: LocalizedStringKey, value: String, icon: String) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(DS.Color.tabLife)

            Text(value)
                .font(.title2.bold())

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Heatmap (expanded)

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Activity Map")
                .font(.headline)

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

    // MARK: - Weekday Breakdown

    private var weekdayBreakdownCard: some View {
        let stats = weekdayStats
        let maxTotal = stats.map(\.count).max() ?? 1

        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("By Weekday")
                .font(.headline)

            ForEach(stats, id: \.weekday) { stat in
                HStack {
                    Text(stat.name)
                        .font(.subheadline)
                        .fixedSize(horizontal: true, vertical: false)

                    GeometryReader { geometry in
                        let barWidth = maxTotal > 0
                            ? geometry.size.width * CGFloat(stat.count) / CGFloat(maxTotal)
                            : 0

                        RoundedRectangle(cornerRadius: 4)
                            .fill(DS.Color.tabLife.opacity(0.6))
                            .frame(width: max(0, barWidth), height: 12)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 20)

                    Text("\(stat.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Computed Stats

    private var validData: [DailyCompletionCount] {
        data.filter { $0.completionCount >= 0 }
    }

    private var totalCompletions: Int {
        validData.reduce(0) { $0 + $1.completionCount }
    }

    private var dailyAverage: Double {
        guard !validData.isEmpty else { return 0 }
        return Double(totalCompletions) / Double(validData.count)
    }

    private var activeDays: Int {
        validData.filter { $0.completionCount > 0 }.count
    }

    private var longestStreak: Int {
        var maxStreak = 0
        var currentStreak = 0
        for item in validData {
            if item.completionCount > 0 {
                currentStreak += 1
                maxStreak = Swift.max(maxStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }
        return maxStreak
    }

    private struct WeekdayStat {
        let weekday: Int
        let name: String
        let count: Int
    }

    private var weekdayStats: [WeekdayStat] {
        let calendar = Calendar.current
        let names = [
            String(localized: "Mon"),
            String(localized: "Tue"),
            String(localized: "Wed"),
            String(localized: "Thu"),
            String(localized: "Fri"),
            String(localized: "Sat"),
            String(localized: "Sun"),
        ]
        var counts = Array(repeating: 0, count: 7)

        for item in validData where item.completionCount > 0 {
            let weekday = calendar.component(.weekday, from: item.date)
            let mondayIndex = (weekday + 5) % 7
            counts[mondayIndex] += item.completionCount
        }

        return (0..<7).map { i in
            WeekdayStat(weekday: i, name: names[i], count: counts[i])
        }
    }
}

// MARK: - Shared Heatmap Grid (fills available width)

struct HabitHeatmapGridView: View {
    let data: [DailyCompletionCount]

    private let cellSpacing: CGFloat = 3
    private let rows = 7

    private static let dayLabels: [String] = [
        String(localized: "Mon"),
        String(localized: "Tue"),
        String(localized: "Wed"),
        String(localized: "Thu"),
        String(localized: "Fri"),
        String(localized: "Sat"),
        String(localized: "Sun"),
    ]

    var body: some View {
        HabitHeatmapLayout(columnCount: columns.count, spacing: cellSpacing) {
            ForEach(0..<rows, id: \.self) { row in
                Text(Self.dayLabels[row])
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            ForEach(paddedData) { item in
                RoundedRectangle(cornerRadius: 2)
                    .fill(cellColor(for: item))
            }
        }
    }

    // MARK: - Column Data

    private struct GridColumn: Sendable {
        let index: Int
        let items: [DailyCompletionCount]
    }

    private var columns: [GridColumn] {
        let items = paddedData
        var result: [GridColumn] = []
        var i = 0
        var colIndex = 0
        while i < items.count {
            let end = min(i + rows, items.count)
            result.append(GridColumn(index: colIndex, items: Array(items[i..<end])))
            i = end
            colIndex += 1
        }
        return result
    }

    // MARK: - Data

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
}

// MARK: - Shared Legend

struct HabitHeatmapLegend: View {
    private static let levels: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text("Less")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ForEach(Self.levels.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.Color.tabLife.opacity(0.08 + Self.levels[index] * 0.8))
                    .frame(width: 12, height: 12)
            }

            Text("More")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// Resolves square cells from the proposed width, including inside a Button label.
private struct HabitHeatmapLayout: Layout {
    let columnCount: Int
    let spacing: CGFloat

    private func metrics(width: CGFloat?, subviews: Subviews) -> (width: CGFloat, label: CGFloat, cell: CGFloat, row: CGFloat) {
        let labels = subviews.prefix(7).map { $0.sizeThatFits(.unspecified) }
        let label = labels.map(\.width).max() ?? 0
        let width = max(label + spacing, width ?? 320)
        let count = max(1, columnCount)
        let cell = max(1, (width - label - spacing - CGFloat(count - 1) * spacing) / CGFloat(count))
        let row = max(cell, labels.map(\.height).max() ?? 0)
        return (width, label, cell, row)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = metrics(width: proposal.width, subviews: subviews)
        return CGSize(width: sizes.width, height: 7 * sizes.row + 6 * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = metrics(width: bounds.width, subviews: subviews)
        for index in subviews.indices {
            if index < 7 {
                subviews[index].place(
                    at: CGPoint(x: bounds.minX, y: bounds.minY + CGFloat(index) * (sizes.row + spacing) + sizes.row / 2),
                    anchor: .leading,
                    proposal: .unspecified
                )
            } else {
                let item = index - 7
                subviews[index].place(
                    at: CGPoint(x: bounds.minX + sizes.label + spacing + CGFloat(item / 7) * (sizes.cell + spacing),
                                y: bounds.minY + CGFloat(item % 7) * (sizes.row + spacing) + (sizes.row - sizes.cell) / 2),
                    proposal: ProposedViewSize(width: sizes.cell, height: sizes.cell)
                )
            }
        }
    }
}
