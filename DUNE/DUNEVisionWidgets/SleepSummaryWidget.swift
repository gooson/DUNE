import SwiftUI
import WidgetKit

/// Spatial Widget displaying last night's sleep summary.
/// Shows total sleep time, sleep score, and a mini stage breakdown.
struct SleepSummaryWidget: Widget {
    let kind = "SleepSummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SleepSummaryProvider()) { entry in
            SleepSummaryWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Sleep Summary")
        .description("Last night's sleep duration and quality breakdown.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Provider

struct SleepSummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> SleepSummaryEntry {
        SleepSummaryEntry(
            date: .now,
            totalHours: 7.2,
            sleepScore: 82,
            stages: SleepStageBreakdown(awake: 0.05, core: 0.45, deep: 0.25, rem: 0.25)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SleepSummaryEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SleepSummaryEntry>) -> Void) {
        let entry = SleepSummaryEntry(
            date: .now,
            totalHours: 7.2,
            sleepScore: 82,
            stages: SleepStageBreakdown(awake: 0.05, core: 0.45, deep: 0.25, rem: 0.25)
        )
        // Refresh at next 10 AM (after sleep data is typically available)
        let now = Date.now
        var refreshComponents = Calendar.current.dateComponents([.year, .month, .day], from: now)
        refreshComponents.hour = 10
        var nextUpdate = Calendar.current.date(from: refreshComponents) ?? now
        if nextUpdate <= now {
            nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: nextUpdate) ?? Calendar.current.date(byAdding: .hour, value: 2, to: now)!
        }
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Entry

struct SleepSummaryEntry: TimelineEntry {
    let date: Date
    let totalHours: Double
    let sleepScore: Int
    let stages: SleepStageBreakdown
}

struct SleepStageBreakdown {
    let awake: Double
    let core: Double
    let deep: Double
    let rem: Double
}

// MARK: - Widget View

struct SleepSummaryWidgetView: View {
    let entry: SleepSummaryEntry

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
            Image(systemName: "moon.fill")
                .font(.title2)
                .foregroundStyle(.indigo)

            Text(formattedHours)
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text("Sleep Score: \(entry.sleepScore)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            stageBar
        }
    }

    private var mediumView: some View {
        HStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "moon.fill")
                    .font(.title)
                    .foregroundStyle(.indigo)

                Text(formattedHours)
                    .font(.system(size: 40, weight: .bold, design: .rounded))

                Text("Sleep Score: \(entry.sleepScore)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                stageRow(label: "Awake", fraction: entry.stages.awake, color: .red)
                stageRow(label: "Core", fraction: entry.stages.core, color: .cyan)
                stageRow(label: "Deep", fraction: entry.stages.deep, color: .indigo)
                stageRow(label: "REM", fraction: entry.stages.rem, color: .teal)

                stageBar
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Components

    private var formattedHours: String {
        let hours = Int(entry.totalHours)
        let minutes = Int((entry.totalHours - Double(hours)) * 60)
        return "\(hours)h \(minutes)m"
    }

    private var stageBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                stageSegment(fraction: entry.stages.awake, color: .red, width: geometry.size.width)
                stageSegment(fraction: entry.stages.core, color: .cyan, width: geometry.size.width)
                stageSegment(fraction: entry.stages.deep, color: .indigo, width: geometry.size.width)
                stageSegment(fraction: entry.stages.rem, color: .teal, width: geometry.size.width)
            }
        }
        .frame(height: 8)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func stageSegment(fraction: Double, color: Color, width: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: width * fraction)
    }

    private func stageRow(label: String, fraction: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(Int(fraction * 100))%")
                .font(.caption2.bold())
        }
    }
}
