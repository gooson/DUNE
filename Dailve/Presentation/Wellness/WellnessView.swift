import SwiftUI
import SwiftData
import Charts

struct WellnessView: View {
    @State private var sleepViewModel = SleepViewModel()
    @State private var bodyViewModel = BodyCompositionViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyCompositionRecord.date, order: .reverse) private var records: [BodyCompositionRecord]

    @State private var cachedBodyItems: [BodyCompositionListItem] = []

    private var isFullyEmpty: Bool {
        let sleepEmpty = sleepViewModel.weeklyData.isEmpty && sleepViewModel.sleepScore == 0
        let bodyEmpty = records.isEmpty && bodyViewModel.healthKitItems.isEmpty
        return sleepEmpty && bodyEmpty && !sleepViewModel.isLoading && !bodyViewModel.isLoadingHealthKit
    }

    private var isLoading: Bool {
        (sleepViewModel.isLoading && sleepViewModel.weeklyData.isEmpty)
        || (bodyViewModel.isLoadingHealthKit && records.isEmpty && bodyViewModel.healthKitItems.isEmpty)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isFullyEmpty {
                EmptyStateView(
                    icon: "leaf.fill",
                    title: "No Wellness Data",
                    message: "Wear Apple Watch to bed for sleep tracking, or add body composition records to get started."
                )
            } else {
                scrollContent
            }
        }
        .background {
            LinearGradient(
                colors: [DS.Color.sleep.opacity(0.03), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    bodyViewModel.resetForm()
                    bodyViewModel.isShowingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add body record")
            }
        }
        .sheet(isPresented: $bodyViewModel.isShowingAddSheet) {
            BodyCompositionFormSheet(
                viewModel: bodyViewModel,
                isEdit: false,
                onSave: {
                    if let record = bodyViewModel.createValidatedRecord() {
                        modelContext.insert(record)
                        bodyViewModel.resetForm()
                        bodyViewModel.isShowingAddSheet = false
                    }
                }
            )
        }
        .sheet(isPresented: $bodyViewModel.isShowingEditSheet) {
            if let record = bodyViewModel.editingRecord {
                BodyCompositionFormSheet(
                    viewModel: bodyViewModel,
                    isEdit: true,
                    onSave: {
                        if bodyViewModel.applyUpdate(to: record) {
                            bodyViewModel.isShowingEditSheet = false
                            bodyViewModel.editingRecord = nil
                        }
                    }
                )
            }
        }
        .navigationDestination(for: BodyHistoryDestination.self) { _ in
            BodyHistoryDetailView(viewModel: bodyViewModel)
        }
        .refreshable {
            async let sleepLoad: () = sleepViewModel.loadData()
            async let bodyLoad: () = bodyViewModel.loadHealthKitData()
            _ = await (sleepLoad, bodyLoad)
            refreshBodyItemsCache()
        }
        .task {
            async let sleepLoad: () = sleepViewModel.loadData()
            async let bodyLoad: () = bodyViewModel.loadHealthKitData()
            _ = await (sleepLoad, bodyLoad)
            refreshBodyItemsCache()
        }
        .onChange(of: records.count) { _, _ in
            refreshBodyItemsCache()
        }
        .onChange(of: bodyViewModel.healthKitItems.count) { _, _ in
            refreshBodyItemsCache()
        }
        .navigationTitle("Wellness")
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                // Error banner (non-blocking)
                if let error = sleepViewModel.errorMessage {
                    errorBanner(error) {
                        Task { await sleepViewModel.loadData() }
                    }
                }

                sleepSection
                bodySection
            }
            .padding()
        }
    }

    // MARK: - Sleep Section

    @ViewBuilder
    private var sleepSection: some View {
        let hasSleepData = sleepViewModel.sleepScore > 0 || !sleepViewModel.weeklyData.isEmpty

        if hasSleepData {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Sleep")
                    .font(DS.Typography.sectionTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if sleepViewModel.isShowingHistoricalData, let date = sleepViewModel.latestSleepDate {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                        Text("Showing data from \(date, style: .date)")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }

                if sleepViewModel.sleepScore > 0 {
                    SleepHeroCard(
                        sleepScore: sleepViewModel.sleepScore,
                        totalMinutes: sleepViewModel.totalSleepMinutes,
                        efficiency: sleepViewModel.sleepEfficiency,
                        stageBreakdown: sleepViewModel.stageBreakdown
                    )
                }

                if !sleepViewModel.weeklyData.isEmpty {
                    sleepTrendCard
                }
            }
        } else {
            miniEmptyState(
                icon: "moon.zzz.fill",
                message: "Wear Apple Watch to bed to track sleep"
            )
        }
    }

    // MARK: - Body Section

    @ViewBuilder
    private var bodySection: some View {
        let items = cachedBodyItems

        if !items.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Body")
                    .font(DS.Typography.sectionTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let latest = items.first {
                    let previous = findItemNearSevenDaysAgo(items: items)
                    BodySnapshotCard(latestItem: latest, previousItem: previous)
                }

                let weightItems = items.filter { $0.weight != nil }
                if weightItems.count >= 2 {
                    weightTrendChart(weightItems)
                }

                NavigationLink(value: BodyHistoryDestination()) {
                    HStack {
                        Text("View All Records")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(DS.Spacing.md)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plain)
            }
        } else {
            miniEmptyState(
                icon: "figure.stand",
                message: "Add your first body composition record"
            )
        }
    }

    // MARK: - Charts

    private var sleepTrendCard: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Weekly Trend")
                    .font(.headline)

                Chart(sleepViewModel.weeklyData) { day in
                    BarMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Hours", day.totalMinutes / 60)
                    )
                    .foregroundStyle(DS.Color.sleep.gradient)
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel {
                            if let hours = value.as(Double.self) {
                                Text("\(Int(hours))h")
                            }
                        }
                        AxisGridLine()
                    }
                }
                .frame(height: 120)

                let totalMinutes = sleepViewModel.weeklyData.map(\.totalMinutes).reduce(0, +)
                let avgMinutes = sleepViewModel.weeklyData.isEmpty ? 0 : totalMinutes / Double(sleepViewModel.weeklyData.count)
                Text("Avg \(avgMinutes.hoursMinutesFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func weightTrendChart(_ weightItems: [BodyCompositionListItem]) -> some View {
        // Items are sorted descending; reverse for chronological chart display
        let chronological = Array(weightItems.reversed())

        return StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Weight Trend")
                    .font(.headline)

                Chart(chronological, id: \.id) { item in
                    if let weight = item.weight {
                        LineMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Weight", weight)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(DS.Color.body)

                        PointMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Weight", weight)
                        )
                        .foregroundStyle(DS.Color.body)
                        .symbolSize(30)
                    }
                }
                .frame(height: 120)
            }
        }
    }

    // MARK: - Helpers

    private func errorBanner(_ message: String, retry: @escaping () -> Void) -> some View {
        InlineCard {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.Color.caution)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer()

                Button("Retry", action: retry)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }

    private func miniEmptyState(icon: String, message: String) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.quaternary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxl)
    }

    /// Maximum age difference (in days) from the 7-day target to accept as comparison data.
    private static let comparisonWindowDays = 10

    private func findItemNearSevenDaysAgo(items: [BodyCompositionListItem]) -> BodyCompositionListItem? {
        guard let latest = items.first else { return nil }
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: latest.date) ?? latest.date
        let threshold = Calendar.current.date(byAdding: .day, value: -Self.comparisonWindowDays, to: latest.date) ?? latest.date
        // Only consider items within the comparison window to avoid misleading stale comparisons
        return items.dropFirst()
            .filter { $0.date >= threshold }
            .min(by: {
                abs($0.date.timeIntervalSince(sevenDaysAgo)) < abs($1.date.timeIntervalSince(sevenDaysAgo))
            })
    }

    private func refreshBodyItemsCache() {
        cachedBodyItems = bodyViewModel.allItems(manualRecords: records)
    }
}

// MARK: - Navigation Destination

struct BodyHistoryDestination: Hashable {}

#Preview {
    NavigationStack {
        WellnessView()
    }
    .modelContainer(for: BodyCompositionRecord.self, inMemory: true)
}
