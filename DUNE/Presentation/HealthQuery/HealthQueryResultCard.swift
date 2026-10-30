import Charts
import SwiftUI

struct HealthQueryResultCard: View {
    let result: HealthQueryResult
    let queryService: any HealthQuerying
    let searchText: String?
    @State private var showingSpeech = false
    @State private var showingReportPreview = false
    @ScaledMetric(relativeTo: .largeTitle) private var heroFontSize = 56

    init(result: HealthQueryResult, queryService: any HealthQuerying = HealthQueryService.shared,
         searchText: String? = nil) {
        self.result = result
        self.queryService = queryService
        self.searchText = searchText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Label(result.title, systemImage: result.kind.symbolName)
                .font(.title2.bold())
                .accessibilityIdentifier("health-query-result-kind-\(result.kind.rawValue)")
            Text("Period: \(result.interval.start.formatted(date: .abbreviated, time: .omitted)) – \(result.interval.end.addingTimeInterval(-0.001).formatted(date: .abbreviated, time: .omitted))")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
                .accessibilityIdentifier("health-query-result")
            if result.status == .locked {
                Label("Unlock your device to view health data.", systemImage: "lock")
            } else if result.status == .noData {
                Label("No records found for this period.", systemImage: "tray")
                    .accessibilityIdentifier("health-query-no-data")
            } else if result.status == .invalidRequest {
                Label("This request needs changes.", systemImage: "exclamationmark.circle")
            } else if result.status == .unavailable {
                Label("This information is unavailable.", systemImage: "exclamationmark.circle")
            } else {
                availableContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private var availableContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if [.latestWorkout, .strengthSets, .personalRecord, .cardioDetail].contains(result.kind),
               let record = result.records.first {
                Text(record.name).font(.title3.bold())
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline).foregroundStyle(DS.Color.textSecondary)
            }
            kindVisual
            if !usesKindVisualForPrimaryMetrics, let metric = heroMetric, metric.value.isFinite {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(metric.title).font(.subheadline)
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                            heroValue(metric)
                            if !metric.unit.displayUnit(for: metric.value).isEmpty {
                                Text(metric.unit.displayUnit(for: metric.value)).font(.headline)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            heroValue(metric)
                            if !metric.unit.displayUnit(for: metric.value).isEmpty {
                                Text(metric.unit.displayUnit(for: metric.value)).font(.headline)
                            }
                        }
                    }
                    if let date = metric.date, shouldShowMetricDate(date, isHero: true) {
                        Text(date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                    }
                    if let previous = metric.comparisonValue, previous.isFinite {
                        Text("Previous: \(metric.unit.formatted(previous)) \(metric.unit.displayUnit(for: previous))")
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                        if let comparisonDate = metric.comparisonDate {
                            Text(comparisonDate.formatted(date: .abbreviated, time: .omitted)).font(.caption)
                        }
                    }
                }
            }
            if result.kind == .sleep, !sleepStages.isEmpty {
                sleepStageSummary
            }
            ForEach(secondaryMetrics) { metric in
                if metric.value.isFinite {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                            Text(metric.title).fixedSize(horizontal: true, vertical: false)
                            Spacer(minLength: 0)
                            Text(metric.unit.displayValue(metric.value))
                                .bold().fixedSize(horizontal: true, vertical: false)
                        }
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(metric.title)
                            Text(metric.unit.displayValue(metric.value)).bold()
                        }
                    }
                    .font(.subheadline)
                    if let comparison = metric.comparisonValue, comparison.isFinite {
                        Text("Previous: \(metric.unit.formatted(comparison)) \(metric.unit.displayUnit(for: comparison))")
                            .font(.caption).foregroundStyle(DS.Color.textSecondary)
                    }
                    if let date = metric.date, shouldShowMetricDate(date, isHero: false) {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(DS.Color.textSecondary)
                    }
                    if let date = metric.comparisonDate {
                        Text("Previous: \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundStyle(DS.Color.textSecondary)
                    }
                }
            }
            ForEach(result.series) { series in
                if !series.points.isEmpty {
                    VStack(alignment: .leading) {
                        Text(series.title).font(.headline)
                        Chart(Array(series.points.filter(\.value.isFinite).suffix(120))) { point in
                            if point.value.isFinite {
                                switch result.kind {
                                case .workoutSummary, .sleep:
                                    BarMark(x: .value("Date", point.date), y: .value(series.unit.symbol, point.value))
                                default:
                                    LineMark(x: .value("Date", point.date), y: .value(series.unit.symbol, point.value))
                                    .foregroundStyle(DS.Color.warmGlow)
                                    PointMark(x: .value("Date", point.date), y: .value(series.unit.symbol, point.value))
                                    .foregroundStyle(DS.Color.warmGlow)
                                }
                            }
                        }
                        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                        .chartYAxis { AxisMarks(position: .leading) }
                        .chartYAxisLabel(position: .leading) { Text(verbatim: series.unit.symbol) }
                        .frame(height: 180)
                        .clipped()
                        .accessibilityLabel(series.title)
                        .accessibilityValue(String(localized: "Chart of dated measurements"))
                        if series.points.count > 120 {
                            Text("Showing the latest 120 chart points.")
                                .font(.caption).foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                }
            }
            ForEach(result.kind == .report ? [] : result.records) { record in
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(record.name).font(.headline)
                    Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                    ForEach(record.completedSets) { set in
                        HStack {
                            Text("Set \(set.number)")
                            Spacer()
                            if let weight = set.weightKilograms { Text("\(weight.formatted()) kg") }
                            if let reps = set.reps { Text("× \(reps)") }
                            if let duration = set.durationSeconds { Text(HealthQueryUnit.seconds.formatted(duration)) }
                            if let distance = set.distanceMeters { Text("\(distance.formatted()) m") }
                        }.font(.subheadline)
                    }
                    if !record.memo.isEmpty {
                        if result.kind == .memoSearch, let searchText,
                           !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            highlightedMemo(record.memo, searchText: searchText).font(.body)
                        } else {
                            Text(record.memo).font(.body)
                        }
                    }
                    if record.localRecordID != nil || record.healthKitWorkoutID != nil {
                        NavigationLink {
                            HealthQueryRecordDetailView(snapshot: record, queryService: queryService)
                        } label: {
                            Label("Open record", systemImage: "arrow.up.right")
                        }
                    }
                }
                .padding(DS.Spacing.sm)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .accessibilityIdentifier("health-query-record-\(record.id)")
            }
            if let explanation = result.explanation, !explanation.isEmpty {
                Text(explanation).font(.body)
            }
            ForEach(result.limitations, id: \.self) { limitation in
                Label(limitation, systemImage: "info.circle")
                    .font(.footnote)
            }
            if !result.isComplete || result.status == .partial {
                Text("Some records may be missing.").font(.footnote)
            }
            if result.kind == .report {
                Button("Preview report") { showingReportPreview = true }
                    .accessibilityIdentifier("health-query-preview-report")
                if showingReportPreview {
                    Text(reportText)
                        .accessibilityIdentifier("health-query-report-preview")
                    ShareLink(item: reportText) {
                        Label("Share report", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("health-query-share")
                }
            }
            if !result.spokenSummary.isEmpty {
                DisclosureGroup("Spoken answer", isExpanded: $showingSpeech) {
                    Text(result.spokenSummary)
                }
                .accessibilityIdentifier("health-query-voice")
            }
            if !result.sources.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Sources").font(.headline)
                    ForEach(Array(displayedSources.enumerated()), id: \.offset) { _, source in
                        Text(sourceLabel(source))
                            .font(.caption)
                    }
                    if result.sources.count > 50 {
                        Text("Showing the latest 50 of \(result.sources.count) sources.")
                            .font(.caption).foregroundStyle(DS.Color.textSecondary)
                    }
                    Text("Answer prepared \(result.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                    if let oldestFetchedAt = result.sources.map(\.fetchedAt).min() {
                        Text("Oldest source retrieved \(oldestFetchedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                    }
                }
                .accessibilityIdentifier("health-query-source")
            }
        }
    }

    private var displayedSources: [HealthQuerySource] {
        // newest-first; sources without a measurement use their retrieval time.
        Array(result.sources.sorted {
            ($0.measuredAt ?? $0.fetchedAt) > ($1.measuredAt ?? $1.fetchedAt)
        }.prefix(50))
    }

    private var usesKindVisualForPrimaryMetrics: Bool {
        [.condition, .metricComparison, .workoutComparison, .cardioDetail].contains(result.kind)
    }

    private var secondaryMetrics: [HealthQueryMetric] {
        result.metrics.filter { metric in
            if result.kind == .metricComparison || result.kind == .workoutComparison {
                return metric.comparisonValue?.isFinite != true
            }
            if result.kind == .cardioDetail, ["distance", "pace"].contains(metric.id) { return false }
            if result.kind == .sleep, sleepStages.contains(where: { $0.id == metric.id }) { return false }
            return metric.id != heroMetric?.id
        }
    }

    private func shouldShowMetricDate(_ date: Date, isHero: Bool) -> Bool {
        if [.latestWorkout, .strengthSets, .personalRecord, .cardioDetail].contains(result.kind),
           result.records.first?.date == date { return false }
        if !isHero, !usesKindVisualForPrimaryMetrics, date == heroMetric?.date { return false }
        return true
    }

    private func heroValue(_ metric: HealthQueryMetric) -> some View {
        Text(metric.unit.formatted(metric.value))
            .font(.system(size: heroFontSize, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityIdentifier("health-query-hero-value")
    }

    private var heroMetric: HealthQueryMetric? {
        let preferredID: String
        switch result.kind {
        case .latestWorkout: preferredID = "duration"
        case .workoutSummary, .report: preferredID = "records"
        case .strengthSets, .personalRecord: preferredID = "weight"
        case .cardioDetail: preferredID = "distance"
        case .latestBody, .bodyTrend: preferredID = "weight"
        case .sleep: preferredID = "sleepTotal"
        case .condition: preferredID = "condition"
        case .memoSearch: preferredID = "matches"
        case .metricComparison, .workoutComparison, .longAnalysis: preferredID = result.metrics.first?.id ?? ""
        }
        return result.metrics.first(where: { $0.id == preferredID && $0.value.isFinite })
            ?? result.metrics.first(where: { $0.value.isFinite })
    }

    @ViewBuilder private var kindVisual: some View {
        switch result.kind {
        case .condition:
            if let score = result.metrics.first(where: { $0.unit == .score }), score.value.isFinite {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    ZStack {
                        Circle().stroke(DS.Color.warmGlow.opacity(0.18), lineWidth: 12)
                        Circle().trim(from: 0, to: min(max(score.value / 100, 0), 1))
                            .stroke(DS.Color.warmGlow, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: DS.Spacing.xxs) {
                            Text(score.unit.formatted(score.value)).font(.title.bold())
                                .accessibilityIdentifier("health-query-hero-value")
                            Text("/100").font(.caption)
                        }
                    }
                    .frame(width: min(244, max(104, heroFontSize * 2.2)), height: min(244, max(104, heroFontSize * 2.2)))
                    .accessibilityLabel(score.title + " " + String(localized: "\(score.unit.formatted(score.value)) out of 100"))
                    Text(score.title).font(.subheadline)
                    if let date = score.date {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(DS.Color.textSecondary)
                    }
                }
            }
        case .personalRecord:
            Image(systemName: "medal.fill")
                .font(.system(size: 52)).foregroundStyle(DS.Color.warmGlow)
                .accessibilityHidden(true)
        case .sleep:
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 44)).foregroundStyle(DS.Color.warmGlow)
                .accessibilityHidden(true)
        case .latestBody, .bodyTrend:
            Image(systemName: "scalemass.fill")
                .font(.system(size: 40)).foregroundStyle(DS.Color.warmGlow)
                .accessibilityHidden(true)
        case .cardioDetail:
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Image(systemName: result.kind.symbolName)
                    .font(.system(size: 44)).foregroundStyle(DS.Color.warmGlow)
                    .accessibilityHidden(true)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: DS.Spacing.sm) { cardioValues }
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) { cardioValues }
                }
            }
        case .latestWorkout, .strengthSets:
            Image(systemName: result.kind.symbolName)
                .font(.system(size: 44)).foregroundStyle(DS.Color.warmGlow)
                .accessibilityHidden(true)
        case .metricComparison, .workoutComparison:
            let comparable = result.metrics.filter { $0.value.isFinite && $0.comparisonValue?.isFinite == true }
            if !comparable.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    ForEach(comparable) { metric in comparisonRow(metric) }
                }
            }
        case .memoSearch:
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 40)).foregroundStyle(DS.Color.warmGlow)
                .accessibilityHidden(true)
        case .workoutSummary:
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 40)).foregroundStyle(DS.Color.warmGlow)
                .accessibilityHidden(true)
        case .report:
            Image(systemName: "doc.text.fill")
                .font(.system(size: 40)).foregroundStyle(DS.Color.warmGlow)
                .accessibilityHidden(true)
        case .longAnalysis:
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 40)).foregroundStyle(DS.Color.warmGlow)
                .accessibilityHidden(true)
        }
    }

    private var sleepStages: [HealthQueryMetric] {
        result.metrics.filter {
            ["sleep-deep", "sleep-rem", "sleep-core"].contains($0.id) && $0.value.isFinite && $0.value > 0
        }
    }

    private var sleepStagesTotal: Double { sleepStages.reduce(0) { $0 + $1.value } }

    private var sleepStageSummary: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Recorded sleep stage totals").font(.headline)
            GeometryReader { geometry in
                HStack(spacing: DS.Spacing.xxs) {
                    ForEach(Array(sleepStages.enumerated()), id: \.element.id) { index, stage in
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(DS.Color.sleep.opacity(0.45 + Double(index) * 0.22))
                            .frame(width: max(0, (geometry.size.width - CGFloat(sleepStages.count - 1) * DS.Spacing.xxs)
                                * CGFloat(stage.value / sleepStagesTotal)))
                    }
                }
            }
            .frame(height: 16)
            .accessibilityHidden(true)
            ForEach(sleepStages) { stage in
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                        Text(stage.title).fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 0)
                        Text(stage.unit.displayValue(stage.value))
                            .bold().fixedSize(horizontal: true, vertical: false)
                    }
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(stage.title)
                        Text(stage.unit.displayValue(stage.value)).bold()
                    }
                }
                .font(.subheadline)
            }
        }
    }

    @ViewBuilder private var cardioValues: some View {
        ForEach(result.metrics.filter { ["distance", "pace"].contains($0.id) && $0.value.isFinite }) { metric in
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(metric.title).font(.subheadline)
                Text(metric.unit.displayValue(metric.value)).font(.title.bold())
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier(metric.id == "distance" ? "health-query-hero-value" : "health-query-cardio-pace")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.sm)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }

    private func highlightedMemo(_ memo: String, searchText: String) -> Text {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        guard let firstMatch = memo.range(of: query, options: options) else { return Text(memo) }
        let start = memo.index(firstMatch.lowerBound, offsetBy: -80, limitedBy: memo.startIndex) ?? memo.startIndex
        let end = memo.index(firstMatch.upperBound, offsetBy: 160, limitedBy: memo.endIndex) ?? memo.endIndex
        let excerpt = String(memo[start..<end])
        var output = Text(start == memo.startIndex ? "" : "…")
        var cursor = excerpt.startIndex
        var highlightedCount = 0
        while highlightedCount < 50,
              let match = excerpt.range(of: query, options: options, range: cursor..<excerpt.endIndex),
              match.upperBound > cursor {
            output = output + Text(String(excerpt[cursor..<match.lowerBound]))
                + Text(String(excerpt[match])).bold().foregroundColor(DS.Color.warmGlow)
            cursor = match.upperBound
            highlightedCount += 1
        }
        output = output + Text(String(excerpt[cursor...]))
        return output + Text(end == memo.endIndex ? "" : "…")
    }

    private func comparisonRow(_ metric: HealthQueryMetric) -> some View {
        let previous = metric.comparisonValue ?? metric.value
        let change = metric.value - previous
        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(metric.title).font(.headline)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: DS.Spacing.sm) { comparisonValues(metric, previous: previous) }
                VStack(alignment: .leading, spacing: DS.Spacing.sm) { comparisonValues(metric, previous: previous) }
            }
            Text("Change: \(signedChange(change, unit: metric.unit)) \(metric.unit.displayUnit(for: abs(change)))")
                .font(.subheadline.bold())
            if previous != 0 {
                Text("Relative change: \((change / abs(previous) * 100).formatted(.number.precision(.fractionLength(0...1))))%")
                    .font(.caption)
            }
        }
        .padding(DS.Spacing.sm)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private func signedChange(_ value: Double, unit: HealthQueryUnit) -> String {
        let sign = value < 0 ? "−" : value > 0 ? "+" : ""
        return sign + unit.formatted(abs(value))
    }

    @ViewBuilder private func comparisonValues(_ metric: HealthQueryMetric, previous: Double) -> some View {
        VStack(alignment: .leading) {
            Text("Current").font(.caption)
            Text(metric.unit.formatted(metric.value) + " " + metric.unit.displayUnit(for: metric.value)).bold()
            if result.comparisonInterval != nil {
                Text(verbatim: periodRange(result.interval)).font(.caption)
            } else if let date = metric.date {
                Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
        VStack(alignment: .leading) {
            Text("Previous").font(.caption)
            Text(metric.unit.formatted(previous) + " " + metric.unit.displayUnit(for: previous)).bold()
            if let interval = result.comparisonInterval {
                Text(verbatim: periodRange(interval)).font(.caption)
            } else if let date = metric.comparisonDate {
                Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func periodRange(_ interval: DateInterval) -> String {
        interval.start.formatted(date: .abbreviated, time: .omitted) + " – "
            + interval.end.addingTimeInterval(-0.001).formatted(date: .abbreviated, time: .omitted)
    }

    private var reportText: String {
        ([result.title, result.interval.start.formatted(date: .abbreviated, time: .omitted)
          + " – " + result.interval.end.addingTimeInterval(-0.001).formatted(date: .abbreviated, time: .omitted)] + result.metrics.filter(\.value.isFinite).map {
            "\($0.title): \($0.unit.formatted($0.value)) \($0.unit.displayUnit(for: $0.value))"
        } + result.limitations).joined(separator: "\n")
    }

    private func sourceLabel(_ source: HealthQuerySource) -> String {
        let name: String
        switch source.kind {
        case .app: name = String(localized: "DUNE record")
        case .healthKit: name = String(localized: "Apple Health")
        case .calculated: name = String(localized: "Calculated from records")
        }
        if let date = source.measuredAt {
            return name + " · " + date.formatted(date: .abbreviated, time: .shortened)
        }
        return name
    }
}

