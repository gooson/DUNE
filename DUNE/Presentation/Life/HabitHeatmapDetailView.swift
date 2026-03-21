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
                        .frame(width: 30, alignment: .leading)

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
                        .frame(width: 30, alignment: .trailing)
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
        HStack(alignment: .top, spacing: 4) {
            // Day labels column
            VStack(spacing: cellSpacing) {
                ForEach(0..<rows, id: \.self) { row in
                    Text(Self.dayLabels[row])
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(maxHeight: .infinity)
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            // Grid columns — each column is one week
            HStack(spacing: cellSpacing) {
                ForEach(columns, id: \.index) { col in
                    VStack(spacing: cellSpacing) {
                        ForEach(col.items) { item in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(cellColor(for: item))
                                .aspectRatio(1, contentMode: .fit)
                        }
                        // Fill remaining rows in incomplete last column
                        if col.items.count < rows {
                            ForEach(0..<(rows - col.items.count), id: \.self) { _ in
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
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
