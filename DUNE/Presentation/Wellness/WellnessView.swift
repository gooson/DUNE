import SwiftUI
import SwiftData

struct WellnessView: View {
    @State private var viewModel: WellnessViewModel
    @State private var bodyViewModel = BodyCompositionViewModel()
    @State private var injuryViewModel = InjuryViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let scrollToTopSignal: Int

    private enum ScrollAnchor: Hashable {
        case top
    }

    private var isRegular: Bool { sizeClass == .regular }

    private let refreshSignal: Int

    init(sharedHealthDataService: SharedHealthDataService? = nil, scrollToTopSignal: Int = 0, refreshSignal: Int = 0) {
        _viewModel = State(initialValue: WellnessViewModel(sharedHealthDataService: sharedHealthDataService))
        self.scrollToTopSignal = scrollToTopSignal
        self.refreshSignal = refreshSignal
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id(ScrollAnchor.top)

                VStack(spacing: isRegular ? DS.Spacing.xxl : DS.Spacing.xl) {
                    // Note: injuryRecords check omitted — injuries live in isolated @Query child view
                    if viewModel.isLoading &&
                        viewModel.physicalCards.isEmpty &&
                        viewModel.activeCards.isEmpty &&
                        viewModel.wellnessScore == nil {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if viewModel.physicalCards.isEmpty &&
                                viewModel.activeCards.isEmpty &&
                                viewModel.wellnessScore == nil &&
                                !viewModel.isLoading {
                        EmptyStateView(
                            icon: "leaf.fill",
                            title: "No Wellness Data",
                            message: "Wear Apple Watch to bed for sleep tracking, or add body composition records to get started."
                        )
                    } else {
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
                            .accessibilityIdentifier("wellness-hero-score")
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
                                cardGrid(cards: viewModel.physicalCards)
                            }
                        }

                        // Active Indicators section
                        if !viewModel.activeCards.isEmpty {
                            WellnessSectionGroup(
                                title: "Active Indicators",
                                icon: "heart.text.square",
                                iconColor: DS.Color.vitals
                            ) {
                                cardGrid(cards: viewModel.activeCards)
                            }
                        }

                        // Injury Banner (isolated @Query — re-renders independently)
                        WellnessInjuryBannerView(
                            onEdit: { record in injuryViewModel.startEditing(record) },
                            onAdd: { startAddingInjury() }
                        )

                        // Body History link (isolated @Query — only renders when records exist)
                        BodyHistoryLinkView()
                    }
                }
                .padding(isRegular ? DS.Spacing.xxl : DS.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: scrollToTopSignal) { _, _ in
                withAnimation(DS.Animation.standard) {
                    proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                }
            }
        }
        .background { TabWaveBackground() }
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
                .accessibilityIdentifier("wellness-toolbar-add")
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
                            bodyViewModel.validationError = String(localized: "Failed to save record changes. Please try again.")
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
        .waveRefreshable {
            await viewModel.performRefresh()
        }
        .task(id: refreshSignal) {
            viewModel.loadData()
        }
        .navigationTitle(Text(verbatim: "Wellness"))
    }

    // MARK: - Helpers

    private func partialFailureBanner(_ message: String) -> some View {
        InlineCard {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.Color.caution)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
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

    /// Eager two-column grid — avoids LazyVGrid layout recalculation during scroll bounce.
    private func cardGrid(cards: [VitalCardData]) -> some View {
        let rows: [(left: VitalCardData, right: VitalCardData?)] = stride(from: 0, to: cards.count, by: 2).map { i in
            (left: cards[i], right: i + 1 < cards.count ? cards[i + 1] : nil)
        }
        return VStack(spacing: DS.Spacing.md) {
            ForEach(rows, id: \.left.id) { row in
                HStack(spacing: DS.Spacing.md) {
                    NavigationLink(value: row.left.metric) {
                        VitalCard(data: row.left)
                    }
                    .buttonStyle(.plain)
                    if let right = row.right {
                        NavigationLink(value: right.metric) {
                            VitalCard(data: right)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                    }
                }
            }
        }
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

// MARK: - Isolated @Query Child Views
// Extracted to prevent SwiftData observation from triggering parent ScrollView re-layout.

/// Injury banner with its own @Query — re-renders independently of WellnessView body.
private struct WellnessInjuryBannerView: View {
    @Query(sort: \InjuryRecord.startDate, order: .reverse) private var injuryRecords: [InjuryRecord]
    @Environment(\.appTheme) private var theme

    let onEdit: (InjuryRecord) -> Void
    let onAdd: () -> Void

    var body: some View {
        let activeInjuries = injuryRecords.filter(\.isActive)
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
                        .tint(theme.accentColor)
                    }
                }

                if activeInjuries.isEmpty {
                    InlineCard {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(DS.Color.textSecondary)

                            Text("No active injuries")
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)

                            Spacer()

                            Button("Add") {
                                onAdd()
                            }
                            .font(.caption.weight(.medium))
                            .tint(theme.accentColor)
                        }
                    }
                } else {
                    ForEach(activeInjuries.prefix(3)) { record in
                        InjuryCardView(record: record) {
                            onEdit(record)
                        }
                    }
                }
            }
        }
    }
}

/// Body History link with its own @Query — only renders when records exist.
private struct BodyHistoryLinkView: View {
    @Query(sort: \BodyCompositionRecord.date, order: .reverse) private var records: [BodyCompositionRecord]

    var body: some View {
        if !records.isEmpty {
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
}

#Preview {
    NavigationStack {
        WellnessView()
    }
    .modelContainer(for: [BodyCompositionRecord.self, InjuryRecord.self], inMemory: true)
}
