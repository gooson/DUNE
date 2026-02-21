import SwiftUI
import SwiftData

struct WellnessView: View {
    @State private var viewModel = WellnessViewModel()
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

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.physicalCards.isEmpty && viewModel.activeCards.isEmpty && viewModel.wellnessScore == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.physicalCards.isEmpty && viewModel.activeCards.isEmpty && viewModel.wellnessScore == nil && !viewModel.isLoading {
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
                colors: [DS.Color.fitness.opacity(0.03), .clear],
                startPoint: .top,
                endPoint: .center
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
                        injuryViewModel.resetForm()
                        injuryViewModel.isShowingAddSheet = true
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
                        if bodyViewModel.applyUpdate(to: record) {
                            bodyViewModel.isShowingEditSheet = false
                            bodyViewModel.editingRecord = nil
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
                    conditionScore: viewModel.conditionScoreFull
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

                // Injury Banner (conditional)
                if !cachedActiveInjuries.isEmpty {
                    injuryBanner
                }

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

                    Text("Active Injuries")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    NavigationLink(value: InjuryHistoryDestination()) {
                        Text("View All")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }

                ForEach(cachedActiveInjuries.prefix(3)) { record in
                    InjuryCardView(record: record) {
                        injuryViewModel.startEditing(record)
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
