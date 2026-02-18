import SwiftUI
import SwiftData
import Charts

struct ExerciseHistoryView: View {
    @State private var viewModel: ExerciseHistoryViewModel
    @State private var oneRMAnalysis: OneRMAnalysis?
    @State private var shareImage: UIImage?
    @State private var recordToDelete: ExerciseRecord?
    @Environment(\.modelContext) private var modelContext
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.kg.rawValue

    @Query private var exerciseRecords: [ExerciseRecord]
    @State private var recordByID: [UUID: ExerciseRecord] = [:]
    private let oneRMService = OneRMEstimationService()

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .kg
    }

    let exerciseName: String

    init(exerciseDefinitionID: String, exerciseName: String) {
        self.exerciseName = exerciseName
        self._viewModel = State(initialValue: ExerciseHistoryViewModel(
            exerciseDefinitionID: exerciseDefinitionID,
            exerciseName: exerciseName
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                metricPicker
                chartSection
                if let analysis = oneRMAnalysis {
                    OneRMAnalysisSection(analysis: analysis)
                }
                statsCards
                sessionHistory
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            rebuildRecordIndex()
            viewModel.loadHistory(from: exerciseRecords)
            updateOneRMAnalysis()
        }
        .onChange(of: exerciseRecords.count) { _, _ in
            rebuildRecordIndex()
            viewModel.loadHistory(from: exerciseRecords)
            updateOneRMAnalysis()
        }
        .sheet(item: Binding(
            get: { shareImage.map { ShareableImage(image: $0) } },
            set: { if $0 == nil { shareImage = nil } }
        )) { shareable in
            ShareImageSheet(image: shareable.image, title: "\(exerciseName) Workout")
                .presentationDetents([.medium])
        }
        .confirmDeleteRecord($recordToDelete, context: modelContext)
    }

    // MARK: - Metric Picker

    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(ProgressMetric.allCases, id: \.self) { metric in
                    Button {
                        viewModel.selectedMetric = metric
                    } label: {
                        Text(metric.rawValue)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(
                                viewModel.selectedMetric == metric
                                    ? DS.Color.activity
                                    : Color.secondary.opacity(0.15),
                                in: Capsule()
                            )
                            .foregroundStyle(
                                viewModel.selectedMetric == metric ? .white : .primary
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, DS.Spacing.sm)
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if viewModel.chartData.count >= 2 {
                let displayData = convertedChartData(viewModel.chartData)
                let displayTrend = convertedChartData(viewModel.trendLine)

                DotLineChartView(
                    data: displayData,
                    baseline: nil,
                    yAxisLabel: metricYLabel,
                    period: chartPeriod,
                    tintColor: DS.Color.activity,
                    trendLine: displayTrend.count >= 2 ? displayTrend : nil
                )
            } else if viewModel.chartData.count == 1 {
                singleDataPointView
            } else {
                emptyChartView
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private var metricYLabel: String {
        let unit = isWeightMetric ? weightUnit.displayName : viewModel.selectedMetric.unit
        return "\(viewModel.selectedMetric.rawValue) (\(unit))"
    }

    private var isWeightMetric: Bool {
        switch viewModel.selectedMetric {
        case .maxWeight, .totalVolume, .estimatedOneRM: true
        case .totalReps: false
        }
    }

    private var chartPeriod: DotLineChartView.Period {
        let count = viewModel.chartData.count
        if count <= 10 { return .week }
        if count <= 30 { return .month }
        return .quarter
    }

    private func convertedChartData(_ data: [ChartDataPoint]) -> [ChartDataPoint] {
        guard isWeightMetric else { return data }
        return data.map { point in
            ChartDataPoint(date: point.date, value: weightUnit.fromKg(point.value))
        }
    }

    private var singleDataPointView: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("Record more sessions to see trends")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let point = viewModel.chartData.first {
                Text(formattedValue(point.value))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DS.Color.activity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    private var emptyChartView: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No data yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Complete workouts to track your progress")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    // MARK: - Stats

    private var statsCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.md) {
            if let best = viewModel.personalBest {
                statCard(title: "Personal Best", value: formattedValue(best), icon: "trophy.fill", color: .orange)
            }
            statCard(
                title: "Sessions",
                value: "\(viewModel.sessions.count)",
                icon: "calendar",
                color: DS.Color.activity
            )

            if let latest = viewModel.sessions.last, let first = viewModel.sessions.first,
               viewModel.sessions.count >= 2 {
                let latestVal = metricValueForDisplay(latest)
                let firstVal = metricValueForDisplay(first)
                if let lv = latestVal, let fv = firstVal, fv > 0 {
                    let change = ((lv - fv) / fv) * 100
                    if !change.isNaN && !change.isInfinite {
                        statCard(
                            title: "Progress",
                            value: String(format: "%+.1f%%", change),
                            icon: change >= 0 ? "arrow.up.right" : "arrow.down.right",
                            color: change >= 0 ? .green : .red
                        )
                    }
                }
            }

            if !viewModel.sessions.isEmpty {
                let totalReps = viewModel.sessions.map(\.totalReps).reduce(0, +)
                statCard(title: "Total Reps", value: "\(totalReps)", icon: "repeat", color: .blue)
            }
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - Session History

    private var sessionHistory: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Session History")
                .font(.headline)

            ForEach(viewModel.sessions.reversed()) { session in
                sessionRow(session)
            }
        }
    }

    private func sessionRow(_ session: ExerciseHistoryViewModel.SessionSummary) -> some View {
        NavigationLink {
            if let record = recordByID[session.id] {
                ExerciseSessionDetailView(record: record, showHistoryLink: false)
            } else {
                ContentUnavailableView("Record not found", systemImage: "exclamationmark.triangle")
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(session.date, style: .date)
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: DS.Spacing.xs) {
                        Text("\(session.setCount) sets")
                        if let maxW = session.maxWeight {
                            Text("\u{00B7}")
                            Text("\(formattedWeight(maxW)) \(weightUnit.displayName)")
                        }
                        if session.totalReps > 0 {
                            Text("\u{00B7}")
                            Text("\(session.totalReps) reps")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if let oneRM = session.estimatedOneRM {
                    VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                        Text("1RM")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(formattedWeight(oneRM))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DS.Color.activity)
                    }
                }
            }
            .padding(DS.Spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                shareSession(session)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                recordToDelete = recordByID[session.id]
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func shareSession(_ session: ExerciseHistoryViewModel.SessionSummary) {
        guard let record = recordByID[session.id] else { return }
        let input = ExerciseRecordShareInput(
            exerciseType: record.exerciseType,
            date: record.date,
            duration: record.duration,
            bestCalories: record.bestCalories,
            completedSets: record.completedSets.map { set in
                ExerciseRecordShareInput.SetInput(
                    setNumber: set.setNumber,
                    weight: set.weight,
                    reps: set.reps,
                    duration: set.duration,
                    distance: set.distance,
                    setType: set.setType
                )
            }
        )
        let pbString: String? = if let pb = viewModel.personalBest {
            formattedValue(pb)
        } else {
            nil
        }
        let data = WorkoutShareService.buildShareData(from: input, personalBest: pbString)
        shareImage = WorkoutShareService.renderShareImage(data: data, weightUnit: weightUnit)
    }

    // MARK: - Record Index

    private func rebuildRecordIndex() {
        recordByID = Dictionary(uniqueKeysWithValues: exerciseRecords.map { ($0.id, $0) })
    }

    // MARK: - 1RM

    private func updateOneRMAnalysis() {
        let defID = viewModel.exerciseDefinitionID
        let matching = exerciseRecords.filter { $0.exerciseDefinitionID == defID }
        let inputs = matching.map { record in
            OneRMSessionInput(
                date: record.date,
                sets: record.completedSets.map { set in
                    OneRMSetInput(weight: set.weight, reps: set.reps)
                }
            )
        }
        oneRMAnalysis = oneRMService.analyze(sessions: inputs)
    }

    // MARK: - Formatting

    private func formattedValue(_ value: Double) -> String {
        if isWeightMetric {
            let display = weightUnit.fromKg(value)
            return display.formatted(.number.precision(.fractionLength(0...1))) + " " + weightUnit.displayName
        }
        return Int(value).description
    }

    private func formattedWeight(_ kg: Double) -> String {
        weightUnit.fromKg(kg).formatted(.number.precision(.fractionLength(0...1)))
    }

    private func metricValueForDisplay(_ session: ExerciseHistoryViewModel.SessionSummary) -> Double? {
        switch viewModel.selectedMetric {
        case .maxWeight: session.maxWeight
        case .totalVolume: session.totalVolume > 0 ? session.totalVolume : nil
        case .estimatedOneRM: session.estimatedOneRM
        case .totalReps: session.totalReps > 0 ? Double(session.totalReps) : nil
        }
    }
}
