import AppIntents
import SwiftUI
import WidgetKit

enum WidgetMetricChoice: String, AppEnum {
    case condition
    case readiness
    case wellness

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Score"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .condition: "Condition",
        .readiness: "Readiness",
        .wellness: "Wellness",
    ]

    var surfaceMetric: WidgetSurfaceMetric {
        switch self {
        case .condition: .condition
        case .readiness: .readiness
        case .wellness: .wellness
        }
    }
}

struct SingleMetricConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "DUNE Score"
    static let description = IntentDescription("Choose the health score to show.")

    @Parameter(title: "Score") var metric: WidgetMetricChoice

    init() {
        metric = .condition
    }
}

struct SingleMetricEntry: TimelineEntry {
    let date: Date
    let kind: WidgetSurfaceMetric
    let snapshot: WidgetMetricSnapshot
}

struct SingleMetricProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SingleMetricEntry {
        entry(for: .condition, preview: true)
    }

    func snapshot(for configuration: SingleMetricConfiguration, in context: Context) async -> SingleMetricEntry {
        entry(for: configuration.metric.surfaceMetric, preview: context.isPreview)
    }

    func timeline(for configuration: SingleMetricConfiguration, in context: Context) async -> Timeline<SingleMetricEntry> {
        let entry = entry(for: configuration.metric.surfaceMetric, preview: false)
        let nextHour = Calendar.autoupdatingCurrent.nextDate(
            after: entry.date,
            matching: DateComponents(minute: 0),
            matchingPolicy: .nextTime
        ) ?? entry.date.addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(nextHour))
    }

    private func entry(for kind: WidgetSurfaceMetric, preview: Bool) -> SingleMetricEntry {
        if preview {
            let sample = WidgetScoreData(
                conditionScore: 78, conditionStatusRaw: "good", conditionMessage: nil,
                readinessScore: 72, readinessStatusRaw: "moderate", readinessMessage: nil,
                wellnessScore: 65, wellnessStatusRaw: "good", wellnessMessage: nil,
                updatedAt: .now
            )
            return SingleMetricEntry(date: .now, kind: kind, snapshot: sample.metric(kind))
        }
        let data = WidgetScoreData.loadSharedData()
        return SingleMetricEntry(
            date: .now,
            kind: kind,
            snapshot: data?.metric(kind) ?? WidgetMetricSnapshot(score: nil, statusRaw: nil, message: nil)
        )
    }
}

struct SingleMetricWidget: Widget {
    let kind = WidgetSurfaceAccessibility.singleMetricWidgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SingleMetricConfiguration.self, provider: SingleMetricProvider()) { entry in
            SingleMetricWidgetView(entry: entry)
        }
        .configurationDisplayName(String(localized: "DUNE Score"))
        .description(String(localized: "A health score you choose, at a glance."))
        .supportedFamilies(WidgetSingleMetricFamily.allCases.map(\.widgetFamily))
    }
}

struct SingleMetricWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SingleMetricEntry

    private var metric: WidgetMetric {
        let kind = entry.kind
        let snapshot = entry.snapshot
        switch kind {
        case .condition:
            WidgetMetric(kind: kind, title: WidgetMetricText.condition, compactTitle: "C", score: snapshot.score,
                         statusLabel: WidgetDS.labelForConditionStatus(snapshot.statusRaw), message: snapshot.message,
                         color: WidgetDS.colorForConditionStatus(snapshot.statusRaw),
                         icon: WidgetDS.iconForConditionStatus(snapshot.statusRaw))
        case .readiness:
            WidgetMetric(kind: kind, title: WidgetMetricText.readiness, compactTitle: "R", score: snapshot.score,
                         statusLabel: WidgetDS.labelForReadinessStatus(snapshot.statusRaw), message: snapshot.message,
                         color: WidgetDS.colorForReadinessStatus(snapshot.statusRaw),
                         icon: WidgetDS.iconForReadinessStatus(snapshot.statusRaw))
        case .wellness:
            WidgetMetric(kind: kind, title: WidgetMetricText.wellness, compactTitle: "W", score: snapshot.score,
                         statusLabel: WidgetDS.labelForWellnessStatus(snapshot.statusRaw), message: snapshot.message,
                         color: WidgetDS.colorForWellnessStatus(snapshot.statusRaw),
                         icon: WidgetDS.iconForWellnessStatus(snapshot.statusRaw))
        }
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                compactContent
            case .systemMedium:
                wideContent
            case .systemLarge, .systemExtraLargePortrait:
                portraitContent
            default:
                compactContent
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .accessibilityIdentifier("widget-single-\(entry.kind.rawValue)-root")
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            title
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                SingleMetricRingView(metric: metric, size: 60, lineWidth: 6)
                    .privacySensitive()
                Spacer(minLength: 0)
            }
            status
        }
        .padding(WidgetDS.Layout.edgePadding)
    }

    private var wideContent: some View {
        HStack(spacing: 16) {
            SingleMetricRingView(metric: metric, size: 94, lineWidth: 9)
                .privacySensitive()
            VStack(alignment: .leading, spacing: 6) {
                title
                status
                if metric.hasScore { detail }
                Spacer(minLength: 0)
                footer
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(WidgetDS.Layout.edgePadding)
    }

    private var portraitContent: some View {
        GeometryReader { geometry in
            let ringSize = min(min(geometry.size.width * 0.65, geometry.size.height * 0.44), 230)
            VStack(alignment: .leading, spacing: 14) {
                title
                Spacer(minLength: 0)
                SingleMetricRingView(metric: metric, size: ringSize, lineWidth: max(9, ringSize * 0.08))
                    .privacySensitive()
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                status
                    .font(.title3.weight(.semibold))
                if metric.hasScore {
                    detail
                        .font(.subheadline)
                }
                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(WidgetDS.Layout.edgePadding)
        }
    }

    private var title: some View {
        Text(metric.title)
            .font(.headline)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var status: some View {
        HStack(spacing: 5) {
            Image(systemName: metric.icon)
            Text(metric.secondaryText)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(metric.tintColor)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .privacySensitive()
    }

    private var detail: some View {
        Text(metric.detailText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .privacySensitive()
    }

    private var footer: some View {
        Text(WidgetMetricText.today)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}

private struct SingleMetricRingView: View {
    let metric: WidgetMetric
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.12), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: metric.progress)
                .stroke(metric.tintColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(metric.scoreText)
                .font(.system(size: size * 0.31, weight: .bold, design: .rounded))
                .foregroundStyle(metric.hasScore ? metric.tintColor : .primary)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metric.title) \(metric.scoreText) \(metric.secondaryText)")
    }
}

private extension WidgetSingleMetricFamily {
    var widgetFamily: WidgetFamily {
        switch self {
        case .small: .systemSmall
        case .medium: .systemMedium
        case .large: .systemLarge
        case .portrait: .systemExtraLargePortrait
        }
    }
}
