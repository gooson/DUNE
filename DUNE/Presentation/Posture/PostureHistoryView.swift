import SwiftUI
import SwiftData

struct PostureHistoryView: View {
    @State private var viewModel = PostureHistoryViewModel()
    @Query(sort: \PostureAssessmentRecord.date, order: .reverse)
    private var records: [PostureAssessmentRecord]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme

    @State private var isCompareMode = false
    @State private var recordToDelete: PostureAssessmentRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if records.isEmpty {
                    emptyState
                } else {
                    chartSection
                    metricFilterPills
                    statsCards
                    historyList
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .englishNavigationTitle("Posture History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if records.count >= 2 {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation {
                            isCompareMode.toggle()
                            if !isCompareMode {
                                viewModel.comparisonSelection.removeAll()
                            }
                        }
                    } label: {
                        Text(isCompareMode
                            ? String(localized: "Cancel")
                            : String(localized: "Compare"))
                            .font(.subheadline)
                    }
                }
            }
        }
        .background { DetailWaveBackground() }
        .environment(\.waveColor, DS.Color.body)
        .onAppear { viewModel.loadHistory(from: records) }
        .onChange(of: records.count) { _, _ in viewModel.loadHistory(from: records) }
        .onChange(of: viewModel.selectedMetricFilter) { _, _ in viewModel.loadHistory(from: records) }
        .navigationDestination(for: PostureRecordDestination.self) { destination in
            if let record = records.first(where: { $0.id == destination.id }) {
                PostureDetailView(record: record)
            } else {
                ContentUnavailableView("Record not found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationDestination(for: PostureComparisonDestination.self) { destination in
            let sorted = [destination.olderID, destination.newerID]
                .compactMap { id in records.first(where: { $0.id == id }) }
                .sorted { $0.date < $1.date }
            if sorted.count == 2 {
                PostureComparisonView(
                    older: sorted[0],
                    newer: sorted[1],
                    viewModel: viewModel
                )
            } else {
                ContentUnavailableView("Records not found", systemImage: "exclamationmark.triangle")
            }
        }
        .alert(
            String(localized: "Delete Assessment"),
            isPresented: Binding(
                get: { recordToDelete != nil },
                set: { if !$0 { recordToDelete = nil } }
            ),
            presenting: recordToDelete
        ) { record in
            Button(String(localized: "Delete"), role: .destructive) {
                withAnimation {
                    modelContext.delete(record)
                }
                recordToDelete = nil
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                recordToDelete = nil
            }
        } message: { _ in
            Text("This assessment will be permanently deleted.")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label(String(localized: "No Posture Assessments"), systemImage: "figure.stand")
        } description: {
            Text("Capture your first posture assessment to start tracking your progress.")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.xxxl)
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if viewModel.chartData.count >= 2 {
                DotLineChartView(
                    data: viewModel.chartData,
                    baseline: nil,
                    yAxisLabel: chartYLabel,
                    period: chartPeriod,
                    tintColor: DS.Color.body
                )
            } else if viewModel.chartData.count == 1 {
                singleDataPointView
            } else {
                noDataForMetricView
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private var chartYLabel: String {
        if let filter = viewModel.selectedMetricFilter {
            return "\(filter.displayName) Score"
        }
        return String(localized: "Posture Score")
    }

    private var chartPeriod: DotLineChartView.Period {
        let count = viewModel.chartData.count
        if count <= 10 { return .week }
        if count <= 30 { return .month }
        return .quarter
    }

    private var singleDataPointView: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("Record more assessments to see trends")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
            if let point = viewModel.chartData.first {
                Text("\(Int(point.value))")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DS.Color.body)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    private var noDataForMetricView: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No data for this metric")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    // MARK: - Metric Filter

    private var metricFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                filterPill(label: String(localized: "Overall"), isSelected: viewModel.selectedMetricFilter == nil) {
                    viewModel.selectedMetricFilter = nil
                }

                ForEach(PostureMetricType.allCases) { metricType in
                    filterPill(
                        label: metricType.displayName,
                        isSelected: viewModel.selectedMetricFilter == metricType
                    ) {
                        viewModel.selectedMetricFilter = metricType
                    }
                }
            }
            .padding(.top, DS.Spacing.sm)
        }
    }

    private func filterPill(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    isSelected ? DS.Color.body : Color.secondary.opacity(0.15),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats

    private var statsCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.md) {
            statCard(
                title: "Average",
                value: "\(Int(viewModel.averageScore.rounded()))",
                icon: "chart.bar.fill",
                color: DS.Color.body
            )

            statCard(
                title: "Assessments",
                value: "\(viewModel.totalMeasurements)",
                icon: "calendar",
                color: DS.Color.body
            )

            statCard(
                title: "Best",
                value: "\(viewModel.bestScore)",
                icon: "trophy.fill",
                color: .green
            )

            if let change = viewModel.changePercentage {
                statCard(
                    title: "Progress",
                    value: "\(change.formattedWithSeparator(fractionDigits: 1, alwaysShowSign: true))%",
                    icon: change >= 0 ? "arrow.up.right" : "arrow.down.right",
                    color: change >= 0 ? .green : .red
                )
            }
        }
    }

    private func statCard(title: LocalizedStringKey, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - History List

    private var historyList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                if isCompareMode && viewModel.canCompare,
                   let pair = viewModel.comparisonPair {
                    NavigationLink(
                        value: PostureComparisonDestination(olderID: pair.0, newerID: pair.1)
                    ) {
                        Text("Compare Selected")
                            .font(.caption.weight(.medium))
                    }
                    .tint(theme.accentColor)
                }
            }

            ForEach(records) { record in
                recordRow(record)
            }
        }
    }

    private func recordRow(_ record: PostureAssessmentRecord) -> some View {
        recordRowContent(record)
            .padding(DS.Spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .contentShape(Rectangle())
            .contextMenu {
                Button(role: .destructive) {
                    recordToDelete = record
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    @ViewBuilder
    private func recordRowContent(_ record: PostureAssessmentRecord) -> some View {
        if isCompareMode {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: viewModel.comparisonSelection.contains(record.id)
                    ? "checkmark.circle.fill"
                    : "circle")
                    .foregroundStyle(viewModel.comparisonSelection.contains(record.id)
                        ? DS.Color.body
                        : .secondary)

                rowBody(record)
            }
            .onTapGesture {
                viewModel.toggleComparison(record.id)
            }
        } else {
            NavigationLink(value: PostureRecordDestination(id: record.id)) {
                rowBody(record)
            }
            .buttonStyle(.plain)
        }
    }

    private func rowBody(_ record: PostureAssessmentRecord) -> some View {
        HStack(spacing: DS.Spacing.md) {
            scoreCircle(record.overallScore)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.date, style: .date)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: DS.Spacing.xs) {
                    Text(String(localized: "\(record.allMetrics.count) metrics"))
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)

                    if !record.memo.isEmpty {
                        Text("\u{00B7}")
                            .foregroundStyle(DS.Color.textSecondary)
                        Text(record.memo)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if !isCompareMode {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func scoreCircle(_ score: Int) -> some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 4)
                .frame(width: 40, height: 40)

            Circle()
                .trim(from: 0, to: min(1, max(0, CGFloat(score) / 100.0)))
                .stroke(
                    scoreColor(score),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))

            Text("\(score)")
                .font(.caption2.bold())
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        postureScoreColor(score)
    }
}

// MARK: - Navigation Destinations

struct PostureRecordDestination: Hashable {
    let id: UUID
}

struct PostureComparisonDestination: Hashable {
    let olderID: UUID
    let newerID: UUID
}
