import SwiftUI
import WidgetKit

/// Spatial Widget displaying training readiness.
/// Shows whether the user is ready for intense training or should focus on recovery.
struct TrainingReadinessWidget: Widget {
    let kind = "TrainingReadinessWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrainingReadinessProvider()) { entry in
            TrainingReadinessWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Training Readiness")
        .description("Your body's readiness for today's workout based on recovery metrics.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Provider

struct TrainingReadinessProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrainingReadinessEntry {
        TrainingReadinessEntry(date: .now, readiness: .ready, recommendedIntensity: .high, muscleFatigueLevel: 0.3)
    }

    func getSnapshot(in context: Context, completion: @escaping (TrainingReadinessEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrainingReadinessEntry>) -> Void) {
        let entry = TrainingReadinessEntry(
            date: .now,
            readiness: .ready,
            recommendedIntensity: .high,
            muscleFatigueLevel: 0.3
        )
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Entry

struct TrainingReadinessEntry: TimelineEntry {
    let date: Date
    let readiness: ReadinessLevel
    let recommendedIntensity: IntensityLevel
    let muscleFatigueLevel: Double
}

enum ReadinessLevel {
    case ready, moderate, rest

    var label: String {
        switch self {
        case .ready: "Ready"
        case .moderate: "Moderate"
        case .rest: "Rest Day"
        }
    }

    var icon: String {
        switch self {
        case .ready: "checkmark.circle.fill"
        case .moderate: "minus.circle.fill"
        case .rest: "bed.double.fill"
        }
    }

    var color: Color {
        switch self {
        case .ready: .green
        case .moderate: .orange
        case .rest: .red
        }
    }
}

enum IntensityLevel {
    case high, medium, low

    var label: String {
        switch self {
        case .high: "High Intensity"
        case .medium: "Medium Intensity"
        case .low: "Low Intensity"
        }
    }
}

// MARK: - Widget View

struct TrainingReadinessWidgetView: View {
    let entry: TrainingReadinessEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .systemSmall {
            smallView
        } else {
            mediumView
        }
    }

    private var smallView: some View {
        VStack(spacing: 12) {
            Image(systemName: entry.readiness.icon)
                .font(.title)
                .foregroundStyle(entry.readiness.color)

            Text(entry.readiness.label)
                .font(.headline)

            Text(entry.recommendedIntensity.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var mediumView: some View {
        HStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: entry.readiness.icon)
                    .font(.largeTitle)
                    .foregroundStyle(entry.readiness.color)

                Text(entry.readiness.label)
                    .font(.title3.bold())

                Text(entry.recommendedIntensity.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                Text("Muscle Fatigue")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                fatigueMeter

                Text("Recovery")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                HStack(spacing: 4) {
                    recoveryDot(label: "Upper", fatigued: false)
                    recoveryDot(label: "Core", fatigued: false)
                    recoveryDot(label: "Lower", fatigued: true)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var fatigueMeter: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)

                RoundedRectangle(cornerRadius: 4)
                    .fill(fatigueColor)
                    .frame(width: geometry.size.width * entry.muscleFatigueLevel)
            }
        }
        .frame(height: 8)
    }

    private var fatigueColor: Color {
        switch entry.muscleFatigueLevel {
        case ..<0.3: .green
        case 0.3..<0.6: .orange
        default: .red
        }
    }

    private func recoveryDot(label: String, fatigued: Bool) -> some View {
        VStack(spacing: 2) {
            Circle()
                .fill(fatigued ? Color.orange : Color.green)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }
}
