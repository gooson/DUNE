import SwiftUI
import WidgetKit

/// Spatial Widget displaying today's condition score.
/// Shows the overall readiness score with a trend indicator.
/// Mounting styles: elevated (default) for desk/shelf, recessed for wall integration.
struct ConditionScoreWidget: Widget {
    let kind = "ConditionScoreWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ConditionScoreProvider()) { entry in
            ConditionScoreWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Condition Score")
        .description("Today's health condition score based on HRV, RHR, and sleep quality.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Provider

struct ConditionScoreProvider: TimelineProvider {
    func placeholder(in context: Context) -> ConditionScoreEntry {
        ConditionScoreEntry(date: .now, score: 78, trend: .up, grade: .good)
    }

    func getSnapshot(in context: Context, completion: @escaping (ConditionScoreEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ConditionScoreEntry>) -> Void) {
        // In production: fetch from HealthKit / shared SwiftData container via App Group
        let entry = ConditionScoreEntry(
            date: .now,
            score: 78,
            trend: .up,
            grade: .good
        )
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Entry

struct ConditionScoreEntry: TimelineEntry {
    let date: Date
    let score: Int
    let trend: ConditionTrend
    let grade: ConditionGrade
}

enum ConditionTrend {
    case up, down, stable

    var icon: String {
        switch self {
        case .up: "arrow.up.right"
        case .down: "arrow.down.right"
        case .stable: "arrow.right"
        }
    }

    var color: Color {
        switch self {
        case .up: .green
        case .down: .red
        case .stable: .secondary
        }
    }
}

enum ConditionGrade {
    case excellent, good, moderate, poor

    var label: String {
        switch self {
        case .excellent: "Excellent"
        case .good: "Good"
        case .moderate: "Moderate"
        case .poor: "Poor"
        }
    }

    var color: Color {
        switch self {
        case .excellent: .green
        case .good: .blue
        case .moderate: .orange
        case .poor: .red
        }
    }
}

// MARK: - Widget View

struct ConditionScoreWidgetView: View {
    let entry: ConditionScoreEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        @unknown default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            Text(verbatim: "CONDITION")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            Text("\(entry.score)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(entry.grade.color)

            HStack(spacing: 4) {
                Image(systemName: entry.trend.icon)
                    .font(.caption2)
                    .foregroundStyle(entry.trend.color)
                Text(entry.grade.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(verbatim: "CONDITION")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                Text("\(entry.score)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.grade.color)

                HStack(spacing: 4) {
                    Image(systemName: entry.trend.icon)
                        .font(.caption)
                        .foregroundStyle(entry.trend.color)
                    Text(entry.grade.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                metricRow(icon: "waveform.path.ecg", label: "HRV", value: "45 ms")
                metricRow(icon: "heart.fill", label: "RHR", value: "58 bpm")
                metricRow(icon: "moon.fill", label: "Sleep", value: "7.2 hrs")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func metricRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.tint)
                .frame(width: 16)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption2.bold())
        }
    }
}
