import Charts
import Observation
import SwiftUI
import SwiftData

extension HealthQueryKind {
    var symbolName: String {
        switch self {
        case .latestWorkout: "figure.run"
        case .workoutSummary: "chart.bar.fill"
        case .strengthSets: "dumbbell.fill"
        case .personalRecord: "medal.fill"
        case .cardioDetail: "figure.outdoor.cycle"
        case .latestBody: "scalemass.fill"
        case .bodyTrend: "chart.xyaxis.line"
        case .sleep: "moon.stars.fill"
        case .condition: "heart.circle.fill"
        case .metricComparison: "chart.bar.xaxis"
        case .workoutComparison: "arrow.left.arrow.right"
        case .memoSearch: "text.magnifyingglass"
        case .report: "doc.text.fill"
        case .longAnalysis: "waveform.path.ecg"
        }
    }

    var displayName: String {
        switch self {
        case .latestWorkout: String(localized: "Latest workout")
        case .workoutSummary: String(localized: "Workout summary")
        case .strengthSets: String(localized: "Strength sets")
        case .personalRecord: String(localized: "Personal record")
        case .cardioDetail: String(localized: "Cardio detail")
        case .latestBody: String(localized: "Latest body measurements")
        case .bodyTrend: String(localized: "Body trend")
        case .sleep: String(localized: "Sleep")
        case .condition: String(localized: "Condition")
        case .metricComparison: String(localized: "Metric comparison")
        case .workoutComparison: String(localized: "Workout comparison")
        case .memoSearch: String(localized: "Workout notes")
        case .report: String(localized: "Health report")
        case .longAnalysis: String(localized: "Health analysis")
        }
    }
}

extension HealthQueryPeriod {
    var displayName: String {
        switch self {
        case .today: String(localized: "Today")
        case .yesterday: String(localized: "Yesterday")
        case .thisWeek: String(localized: "This week")
        case .lastWeek: String(localized: "Last week")
        case .thisMonth: String(localized: "This month")
        case .lastMonth: String(localized: "Last month")
        case .last7Days: String(localized: "Last 7 days")
        case .last30Days: String(localized: "Last 30 days")
        case .last90Days: String(localized: "Last 90 days")
        case .last365Days: String(localized: "Last 365 days")
        }
    }
}

extension HealthQueryUnit {
    var symbol: String {
        switch self {
        case .count: ""
        case .seconds: "s"
        case .meters: "m"
        case .kilograms: "kg"
        case .kilocalories: "kcal"
        case .bodyMassIndex: "kg/m²"
        case .percent: "%"
        case .bpm: "bpm"
        case .milliseconds: "ms"
        case .score: "/100"
        case .kilogramRepetitions: "kg·reps"
        case .secondsPerKilometer: "s/km"
        }
    }

    func formatted(_ value: Double) -> String {
        guard value.isFinite else { return String(localized: "Unavailable") }
        switch self {
        case .seconds:
            let total = max(0, Int(value))
            let hours = total / 3_600
            let minutes = (total % 3_600) / 60
            let seconds = total % 60
            return hours > 0 ? "\(hours):\(minutes.formatted(.number.precision(.integerLength(2)))):\(seconds.formatted(.number.precision(.integerLength(2))))" : "\(minutes):\(seconds.formatted(.number.precision(.integerLength(2))))"
        case .secondsPerKilometer:
            let minutes = Int(value) / 60
            let seconds = Int(value) % 60
            return "\(minutes):\(seconds.formatted(.number.precision(.integerLength(2))))"
        case .meters where abs(value) >= 1_000:
            return (value / 1_000).formatted(.number.precision(.fractionLength(0...2)))
        case .percent, .kilograms, .kilocalories, .kilogramRepetitions, .bodyMassIndex:
            return value.formatted(.number.precision(.fractionLength(0...1)))
        default:
            return value.formatted(.number.precision(.fractionLength(0...0)))
        }
    }

    func displayUnit(for value: Double) -> String {
        self == .meters && abs(value) >= 1_000 ? "km" : symbol
    }
}

@MainActor @Observable
final class HealthQueryViewModel {
    enum State: Equatable {
        case idle, loading, loaded(HealthQueryResult), failed(String), cancelled
    }

    private let service: any HealthQuerying
    private let assistant: any HealthQueryAssisting
    private var task: Task<Void, Never>?
    private var explanationTask: Task<Void, Never>?
    private var generation = 0
    private(set) var state: State = .idle
    private(set) var isExplaining = false
    private(set) var explanationMessage: String?

    init(service: any HealthQuerying, assistant: (any HealthQueryAssisting)? = nil) {
        self.service = service
        self.assistant = assistant ?? HealthQueryAssistant(queryService: service)
    }

    func load(_ request: HealthQueryRequest) {
        task?.cancel()
        explanationTask?.cancel()
        isExplaining = false
        explanationMessage = nil
        generation += 1
        let currentGeneration = generation
        state = .loading
        task = Task {
            do {
                let result = try await service.execute(request)
                guard !Task.isCancelled, generation == currentGeneration else { return }
                state = .loaded(result)
            } catch is CancellationError {
                guard generation == currentGeneration else { return }
                state = .cancelled
            } catch {
                guard !Task.isCancelled, generation == currentGeneration else { return }
                state = .failed(String(localized: "Could not load health data. Try again."))
            }
        }
    }

    func explainComparison() {
        guard case .loaded(let result) = state,
              result.status == .available || result.status == .partial,
              !result.sources.isEmpty,
              result.metrics.contains(where: { $0.value.isFinite && $0.comparisonValue?.isFinite == true }) else { return }
        explanationTask?.cancel()
        let currentGeneration = generation
        isExplaining = true
        explanationMessage = nil
        explanationTask = Task {
            do {
                let explained = try await assistant.explain(result, useCloud: false)
                guard !Task.isCancelled, generation == currentGeneration else { return }
                state = .loaded(explained)
                if explained.explanationStatus != .generated {
                    explanationMessage = String(localized: "Explanation is unavailable on this device.")
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, generation == currentGeneration else { return }
                explanationMessage = String(localized: "Could not explain this comparison.")
            }
            if generation == currentGeneration { isExplaining = false }
        }
    }

    func clear() {
        cancel()
        state = .idle
    }

    func cancel() {
        generation += 1
        task?.cancel()
        explanationTask?.cancel()
        task = nil
        explanationTask = nil
        isExplaining = false
        state = .cancelled
    }
}

struct HealthQueryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: HealthQueryViewModel
    @State private var kind: HealthQueryKind
    @State private var period: HealthQueryPeriod = .last30Days
    @State private var initialRequest: HealthQueryRequest?
    @State private var searchText: String

    init(queryService: any HealthQuerying, request: HealthQueryRequest? = nil) {
        _model = State(initialValue: HealthQueryViewModel(service: queryService))
        _kind = State(initialValue: request?.kind ?? .latestWorkout)
        _initialRequest = State(initialValue: request)
        _searchText = State(initialValue: request?.searchText ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text("Health information")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("health-query-screen")
                Picker("Information", selection: $kind) {
                    ForEach(HealthQueryKind.allCases, id: \.self) { item in
                        Text(item.displayName).tag(item)
                            .accessibilityIdentifier("health-query-kind-\(item.rawValue)")
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("health-query-kind")
                Picker("Period", selection: $period) {
                    ForEach(HealthQueryPeriod.allCases, id: \.self) { item in
                        Text(item.displayName).tag(item)
                            .accessibilityIdentifier("health-query-period-\(item.rawValue)")
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("health-query-period")
                if kind == .memoSearch {
                    HStack {
                        TextField("Search workout notes", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.search)
                            .onSubmit { load() }
                        Button("Search") { load() }
                            .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                switch model.state {
                case .idle:
                    Text("Enter words from a workout note to search your records.")
                        .foregroundStyle(DS.Color.textSecondary)
                case .loading:
                    InlineCard {
                        HStack(spacing: DS.Spacing.sm) {
                            ProgressView()
                            Text("Reading health records...")
                        }
                    }
                    Button("Cancel analysis") { model.cancel() }
                        .accessibilityIdentifier("health-query-cancel")
                case .loaded(let result):
                    HealthQueryResultCard(result: result)
                        .accessibilityIdentifier("health-query-result")
                    if (result.status == .available || result.status == .partial),
                       !result.sources.isEmpty,
                       result.metrics.contains(where: { $0.value.isFinite && $0.comparisonValue?.isFinite == true }) {
                        Button("Explain comparison") { model.explainComparison() }
                            .disabled(model.isExplaining)
                        if model.isExplaining { ProgressView("Explaining comparison...") }
                        if let message = model.explanationMessage {
                            Text(message).font(.footnote).foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                case .failed(let message):
                    ContentUnavailableView(message, systemImage: "exclamationmark.circle")
                    Button("Try again") { load() }
                case .cancelled:
                    ContentUnavailableView("Analysis cancelled", systemImage: "xmark.circle")
                    Button("Try again") { load() }
                }
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background { SheetWaveBackground() }
        .navigationTitle("Health information")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .accessibilityIdentifier("health-query-done")
            }
        }
        .task(id: kind) {
            if kind == .memoSearch && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                model.clear()
            } else { load() }
        }
        .onChange(of: period) { _, _ in
            if kind != .memoSearch || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { load() }
        }
        .task { try? await HealthQuerySearchIndex.shared.removeAll() }
        .onDisappear { model.cancel() }
    }

    private func load() {
        var request = initialRequest ?? HealthQueryRequest(kind: kind)
        request.kind = kind
        request.searchText = kind == .memoSearch ? searchText.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        if kind == .memoSearch && request.searchText?.isEmpty != false { model.clear(); return }
        if initialRequest == nil || request.interval == nil {
            request.interval = period.interval(endingAt: .now)
        }
        initialRequest = nil
        model.load(request)
    }
}

struct HealthQueryResultCard: View {
    let result: HealthQueryResult
    @State private var showingSpeech = false
    @State private var showingReportPreview = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Label(result.kind.displayName, systemImage: result.kind.symbolName)
                .font(.title2.bold())
                .accessibilityIdentifier("health-query-result-kind-\(result.kind.rawValue)")
            Text("Period: \(result.interval.start.formatted(date: .abbreviated, time: .omitted)) – \(result.interval.end.formatted(date: .abbreviated, time: .omitted))")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
            if result.status == .locked {
                Label("Unlock your device to view health data.", systemImage: "lock")
            } else if result.status == .noData {
                Label("No records found for this period.", systemImage: "tray")
                    .accessibilityIdentifier("health-query-no-data")
            } else if result.status == .unavailable || result.status == .invalidRequest {
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
            kindVisual
            if let metric = result.metrics.first, metric.value.isFinite {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(metric.title).font(.subheadline)
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        Text(metric.unit.formatted(metric.value)).font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text(metric.unit.displayUnit(for: metric.value)).font(.headline)
                    }
                    if let date = metric.date {
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
            ForEach(result.metrics.dropFirst()) { metric in
                if metric.value.isFinite {
                    HStack(alignment: .firstTextBaseline) {
                        Text(metric.title)
                        Spacer()
                        Text(metric.unit.formatted(metric.value) + " " + metric.unit.displayUnit(for: metric.value))
                            .bold()
                    }
                    .font(.subheadline)
                    if let comparison = metric.comparisonValue, comparison.isFinite {
                        Text("Previous: \(metric.unit.formatted(comparison)) \(metric.unit.displayUnit(for: comparison))")
                            .font(.caption).foregroundStyle(DS.Color.textSecondary)
                    }
                }
            }
            ForEach(result.series) { series in
                if !series.points.isEmpty {
                    VStack(alignment: .leading) {
                        Text(series.title).font(.headline)
                        Chart(series.points) { point in
                            if point.value.isFinite {
                                switch result.kind {
                                case .workoutSummary, .sleep:
                                    BarMark(x: .value("Date", point.date), y: .value(series.unit.symbol, point.value))
                                default:
                                    LineMark(x: .value("Date", point.date), y: .value(series.unit.symbol, point.value))
                                    PointMark(x: .value("Date", point.date), y: .value(series.unit.symbol, point.value))
                                }
                            }
                        }
                        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                        .chartYAxis { AxisMarks(position: .leading) }
                        .frame(height: 180)
                        .clipped()
                    }
                }
            }
            ForEach(result.records) { record in
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
                    if !record.memo.isEmpty { Text(record.memo).font(.body) }
                    if record.localRecordID != nil || record.healthKitWorkoutID != nil {
                        NavigationLink {
                            HealthQueryRecordDetailView(snapshot: record)
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
                    ForEach(Array(result.sources.enumerated()), id: \.offset) { _, source in
                        Text(sourceLabel(source))
                            .font(.caption)
                    }
                    Text("Updated \(result.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                }
                .accessibilityIdentifier("health-query-source")
            }
        }
    }

    @ViewBuilder private var kindVisual: some View {
        switch result.kind {
        case .condition:
            if let score = result.metrics.first(where: { $0.unit == .score }), score.value.isFinite {
                ZStack {
                    Circle().stroke(DS.Color.warmGlow.opacity(0.18), lineWidth: 12)
                    Circle().trim(from: 0, to: min(max(score.value / 100, 0), 1))
                        .stroke(DS.Color.warmGlow, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(score.unit.formatted(score.value)).font(.title.bold())
                }
                .frame(width: 104, height: 104)
                .accessibilityLabel(score.title + " " + score.unit.formatted(score.value))
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
        case .latestWorkout, .strengthSets, .cardioDetail:
            Image(systemName: result.kind.symbolName)
                .font(.system(size: 44)).foregroundStyle(DS.Color.warmGlow)
                .accessibilityHidden(true)
        case .metricComparison, .workoutComparison:
            if result.metrics.count >= 2 {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    ForEach(result.metrics.prefix(2)) { metric in
                        VStack(alignment: .leading) {
                            Text(metric.title).font(.caption)
                            Text(metric.unit.formatted(metric.value)).font(.title2.bold())
                            Text(metric.unit.displayUnit(for: metric.value)).font(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Spacing.sm)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
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

    private var reportText: String {
        ([result.title, result.interval.start.formatted(date: .abbreviated, time: .omitted)
          + " – " + result.interval.end.formatted(date: .abbreviated, time: .omitted), result.spokenSummary] + result.metrics.map {
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

private struct HealthQueryRecordDetailView: View {
    let snapshot: HealthQueryWorkoutSnapshot
    @Environment(\.modelContext) private var modelContext
    @State private var manualRecord: ExerciseRecord?
    @State private var healthWorkout: WorkoutSummary?
    @State private var finishedLoading = false

    var body: some View {
        Group {
            if let manualRecord {
                ExerciseSessionDetailView(record: manualRecord, activityType: snapshot.activityType ?? .other,
                                          displayName: snapshot.name)
            } else if let healthWorkout {
                HealthKitWorkoutDetailView(workout: healthWorkout)
            } else if finishedLoading {
                ContentUnavailableView("Record no longer available", systemImage: "tray")
            } else {
                ProgressView("Opening record...")
            }
        }
        .task(id: snapshot.id) {
            if let localID = snapshot.localRecordID {
                let descriptor = FetchDescriptor<ExerciseRecord>(predicate: #Predicate { $0.id == localID })
                manualRecord = try? modelContext.fetch(descriptor).first
            }
            if manualRecord == nil, let workoutID = snapshot.healthKitWorkoutID {
                let start = snapshot.date.addingTimeInterval(-86_400)
                let end = snapshot.date.addingTimeInterval(86_400)
                let workouts = try? await WorkoutQueryService(manager: .shared).fetchWorkouts(start: start, end: end)
                healthWorkout = workouts?.first { $0.id == workoutID }
            }
            finishedLoading = true
        }
    }
}

#Preview {
    NavigationStack {
        HealthQueryView(queryService: PreviewHealthQueryService())
    }
}

@MainActor private struct PreviewHealthQueryService: HealthQuerying {
    func execute(_ request: HealthQueryRequest) async throws -> HealthQueryResult {
        HealthQueryResult(kind: request.kind, status: .noData, title: request.kind.displayName,
                          generatedAt: .now, interval: request.interval ?? HealthQueryPeriod.today.interval(endingAt: .now),
                          spokenSummary: "")
    }
}
