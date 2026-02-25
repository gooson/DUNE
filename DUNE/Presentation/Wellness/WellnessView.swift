import SwiftUI
import SwiftData

struct WellnessView: View {
    @State private var viewModel: WellnessViewModel
    @State private var bodyViewModel = BodyCompositionViewModel()
    @State private var injuryViewModel = InjuryViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \BodyCompositionRecord.date, order: .reverse) private var records: [BodyCompositionRecord]
    @Query(sort: \InjuryRecord.startDate, order: .reverse) private var injuryRecords: [InjuryRecord]

    @State private var cachedActiveInjuries: [InjuryRecord] = []

    private var isRegular: Bool { sizeClass == .regular }

    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md)
    ]

    init(sharedHealthDataService: SharedHealthDataService? = nil) {
        _viewModel = State(initialValue: WellnessViewModel(sharedHealthDataService: sharedHealthDataService))
    }

    var body: some View {
        Group {
            if viewModel.isLoading &&
                viewModel.physicalCards.isEmpty &&
                viewModel.activeCards.isEmpty &&
                viewModel.wellnessScore == nil &&
                injuryRecords.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.physicalCards.isEmpty &&
                        viewModel.activeCards.isEmpty &&
                        viewModel.wellnessScore == nil &&
                        !viewModel.isLoading &&
                        injuryRecords.isEmpty {
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
                colors: [DS.Color.fitness.opacity(0.10), Color.accentColor.opacity(0.06), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.6)
            )
            .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        bodyViewModel.resetForm()
                        bodyViewModel.isShowingAddSheet = true
                    } label: {
                        Label("Body Record", systemImage: "figure.stand")
                    }
                    Button {
                        startAddingInjury()
                    } label: {
                        Label("Injury", systemImage: "bandage.fill")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add record")
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
                        var didUpdate = false
                        do {
                            try modelContext.transaction {
                                didUpdate = bodyViewModel.applyUpdate(to: record)
                            }
                            if didUpdate {
                                bodyViewModel.isShowingEditSheet = false
                                bodyViewModel.editingRecord = nil
                            }
                        } catch {
                            bodyViewModel.validationError = "Failed to save record changes. Please try again."
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $injuryViewModel.isShowingAddSheet) {
            InjuryFormSheet(
                viewModel: injuryViewModel,
                isEdit: false,
                onSave: {
                    if let record = injuryViewModel.createValidatedRecord() {
                        modelContext.insert(record)
                        injuryViewModel.didFinishSaving()
                        injuryViewModel.resetForm()
                        injuryViewModel.isShowingAddSheet = false
                    }
                }
            )
        }
        .sheet(isPresented: $injuryViewModel.isShowingEditSheet) {
            if injuryViewModel.editingRecord != nil {
                InjuryFormSheet(
                    viewModel: injuryViewModel,
                    isEdit: true,
                    onSave: {
                        if let record = injuryViewModel.editingRecord, injuryViewModel.applyUpdate(to: record) {
                            injuryViewModel.isShowingEditSheet = false
                            injuryViewModel.resetForm()
                        }
                    }
                )
            }
        }
        // Correction #48: navigationDestination outside conditional blocks
        .navigationDestination(for: HealthMetric.self) { metric in
            MetricDetailView(metric: metric)
        }
        .navigationDestination(for: AllDataDestination.self) { destination in
            AllDataView(category: destination.category)
        }
        .navigationDestination(for: BodyHistoryDestination.self) { _ in
            BodyHistoryDetailView(viewModel: bodyViewModel)
        }
        .navigationDestination(for: InjuryHistoryDestination.self) { _ in
            InjuryHistoryView(viewModel: injuryViewModel)
        }
        .navigationDestination(for: WellnessScoreDestination.self) { _ in
            if let score = viewModel.wellnessScore {
                WellnessScoreDetailView(
                    wellnessScore: score,
                    conditionScore: viewModel.conditionScoreFull,
                    bodyScoreDetail: viewModel.bodyScoreDetail,
                    sleepDailyData: viewModel.sleepDetailTrend,
                    hrvDailyData: viewModel.hrvDetailTrend,
                    rhrDailyData: viewModel.rhrDetailTrend
                )
            } else {
                ProgressView()
            }
        }
        .refreshable {
            await viewModel.performRefresh()
        }
        .task {
            viewModel.loadData()
            refreshActiveInjuriesCache()
        }
        .onChange(of: injuryRecords.count) { _, _ in
            refreshActiveInjuriesCache()
        }
        .onChange(of: injuryRecords.map(\.endDate)) { _, _ in
            refreshActiveInjuriesCache()
        }
        .navigationTitle("Wellness")
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: isRegular ? DS.Spacing.xxl : DS.Spacing.xl) {
                // Partial failure banner
                if let message = viewModel.partialFailureMessage {
                    partialFailureBanner(message)
                }

                // Hero Card
                if viewModel.wellnessScore != nil {
                    NavigationLink(value: WellnessScoreDestination()) {
                        WellnessHeroCard(
                            score: viewModel.wellnessScore,
                            sleepScore: viewModel.sleepScore,
                            conditionScore: viewModel.conditionScore,
                            bodyScore: viewModel.bodyScore
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    WellnessHeroCard(
                        score: viewModel.wellnessScore,
                        sleepScore: viewModel.sleepScore,
                        conditionScore: viewModel.conditionScore,
                        bodyScore: viewModel.bodyScore
                    )
                }

                // Physical section
                if !viewModel.physicalCards.isEmpty {
                    WellnessSectionGroup(
                        title: "Physical",
                        icon: "figure.stand",
                        iconColor: DS.Color.body
                    ) {
                        LazyVGrid(columns: gridColumns, spacing: DS.Spacing.md) {
                            ForEach(viewModel.physicalCards) { card in
                                NavigationLink(value: card.metric) {
                                    VitalCard(data: card)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Active Indicators section
                if !viewModel.activeCards.isEmpty {
                    WellnessSectionGroup(
                        title: "Active Indicators",
                        icon: "heart.text.square",
                        iconColor: DS.Color.vitals
                    ) {
                        LazyVGrid(columns: gridColumns, spacing: DS.Spacing.md) {
                            ForEach(viewModel.activeCards) { card in
                                NavigationLink(value: card.metric) {
                                    VitalCard(data: card)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Injury Banner
                injuryBanner

                // Body History link
                if records.count > 0 {
                    NavigationLink(value: BodyHistoryDestination()) {
                        HStack {
                            Image(systemName: "figure.stand")
                                .font(.subheadline)
                                .foregroundStyle(DS.Color.body)
                            Text("Body Composition History")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(DS.Spacing.lg)
                        .background {
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .fill(.thinMaterial)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(isRegular ? DS.Spacing.xxl : DS.Spacing.lg)
        }
    }

    // MARK: - Injury Banner

    private var injuryBanner: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "bandage.fill")
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.caution)

                    Text("Injuries")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    if !injuryRecords.isEmpty {
                        NavigationLink(value: InjuryHistoryDestination()) {
                            Text("View All")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }

                if cachedActiveInjuries.isEmpty {
                    InlineCard {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(.secondary)

                            Text("No active injuries")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button("Add") {
                                startAddingInjury()
                            }
                            .font(.caption.weight(.medium))
                        }
                    }
                } else {
                    ForEach(cachedActiveInjuries.prefix(3)) { record in
                        InjuryCardView(record: record) {
                            injuryViewModel.startEditing(record)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func partialFailureBanner(_ message: String) -> some View {
        InlineCard {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.Color.caution)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer()

                Button("Retry") {
                    viewModel.loadData()
                }
                .font(.caption)
                .fontWeight(.medium)
            }
        }
    }

    private func refreshActiveInjuriesCache() {
        cachedActiveInjuries = injuryRecords.filter(\.isActive)
    }

    private func startAddingInjury() {
        injuryViewModel.resetForm()
        injuryViewModel.isShowingAddSheet = true
    }
}

// MARK: - Navigation Destinations

struct WellnessScoreDestination: Hashable {}
struct BodyHistoryDestination: Hashable {}
struct InjuryHistoryDestination: Hashable {}

#Preview {
    NavigationStack {
        WellnessView()
    }
    .modelContainer(for: [BodyCompositionRecord.self, InjuryRecord.self], inMemory: true)
}
