import SwiftUI
import SwiftData

struct WellnessView: View {
    @State private var viewModel: WellnessViewModel
    @State private var bodyViewModel = BodyCompositionViewModel()
    @State private var injuryViewModel = InjuryViewModel()
    @State private var isShowingPostureCapture = false
    @State private var isShowingComparison = false
    @State private var isShowingRealtimePosture = false
    @State private var lastHandledWeightEntrySignal = 0
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let scrollToTopSignal: Int
    private let openWeightEntrySignal: Int

    private enum ScrollAnchor: Hashable {
        case top
    }

    private var isRegular: Bool { sizeClass == .regular }

    private let refreshSignal: Int
    private let scoreRefreshService: ScoreRefreshService?

    init(
        sharedHealthDataService: SharedHealthDataService? = nil,
        scoreRefreshService: ScoreRefreshService? = nil,
        scrollToTopSignal: Int = 0,
        refreshSignal: Int = 0,
        openWeightEntrySignal: Int = 0
    ) {
        _viewModel = State(initialValue: WellnessViewModel(sharedHealthDataService: sharedHealthDataService, scoreRefreshService: scoreRefreshService))
        self.scrollToTopSignal = scrollToTopSignal
        self.refreshSignal = refreshSignal
        self.openWeightEntrySignal = openWeightEntrySignal
        self.scoreRefreshService = scoreRefreshService
    }

    private var comparisonMetrics: [HealthMetric] {
        var seen = Set<String>()
        return (viewModel.physicalCards + viewModel.activeCards).map(\.metric).filter { seen.insert($0.id).inserted }
    }

    private var hasSummaryData: Bool {
        viewModel.wellnessScore != nil || !viewModel.physicalCards.isEmpty || !viewModel.activeCards.isEmpty
    }

    private var sleepMetric: HealthMetric? {
        comparisonMetrics.first { $0.category == .sleep }
    }

    private func openBodyRecord() {
        bodyViewModel.resetForm()
        bodyViewModel.isShowingAddSheet = true
    }


    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(width: 0, height: 0)
                    .id(ScrollAnchor.top)

                VStack(spacing: isRegular ? DS.Spacing.xxl : DS.Spacing.xl) {
                    if viewModel.isLoading && !hasSummaryData {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        if let message = viewModel.partialFailureMessage {
                            partialFailureBanner(message)
                        }

                        if !hasSummaryData {
                            if viewModel.isMirroredReadOnlyMode {
                                CloudSyncWaitingView {
                                    Task { viewModel.loadData() }
                                }
                            } else {
                                EmptyStateView(
                                    icon: "leaf.fill",
                                    title: "No Wellness Data",
                                    message: "Wear Apple Watch to bed for sleep tracking, or add body composition records to get started."
                                )
                            }
                        } else {
                            WellnessHeroCard(
                                score: viewModel.wellnessScore,
                                sleepScore: viewModel.sleepScore,
                                conditionScore: viewModel.conditionScore,
                                bodyScore: viewModel.bodyScore,
                                hourlySparkline: viewModel.wellnessSparkline.nonEmptyOrNil
                            )
                            .reportTabHeroFrame()
                            .staggeredAppear(index: 0)

                            flowPair {
                                WellnessSleepSummaryCard(
                                    sleepTrend: viewModel.sleepDetailTrend,
                                    sleepMetric: sleepMetric
                                )
                            } trailing: {
                                WellnessSleepPredictionCard(prediction: viewModel.sleepPrediction)
                            }
                        }

                        // Independent local records remain available without HealthKit metrics.
                        WellnessInjuryBannerView(
                            placement: .active,
                            onEdit: { injuryViewModel.startEditing($0) },
                            onAdd: { startAddingInjury() }
                        )

                        if hasSummaryData {
                            flowPair {
                                healthIndicatorsSection
                            } trailing: {
                                WellnessBodySummaryCard(
                                    cards: viewModel.physicalCards,
                                    comparisons: viewModel.bodyComparisons,
                                    onAdd: openBodyRecord
                                )
                            }
                        }

                        flowPair {
                            WatchPostureSummaryCard(
                                summary: viewModel.watchPostureSummary,
                                isWatchAppInstalled: WatchSessionManager.shared.isWatchAppInstalled
                            )
                        } trailing: {
                            PostureAssessmentLinkView(
                                onCapture: { isShowingPostureCapture = true },
                                onRealtime: { isShowingRealtimePosture = true },
                                onScoreUpdate: { viewModel.postureScore = $0 }
                            )
                        }

                        WellnessInjuryBannerView(
                            placement: .history,
                            onEdit: { injuryViewModel.startEditing($0) },
                            onAdd: { startAddingInjury() }
                        )
                    }
                }
                .padding(isRegular ? DS.Spacing.xxl : DS.Spacing.lg)
                .frame(maxWidth: isRegular ? DS.Layout.rootContentMaxWidth : .infinity)
                .frame(maxWidth: .infinity)
                .coordinateSpace(name: TabHeroStartLine.coordinateSpace)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: scrollToTopSignal) { _, _ in
                withAnimation(DS.Animation.standard) {
                    proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                }
            }
        }
        .backgroundPreferenceValue(TabHeroFramePreferenceKey.self) { heroFrame in
            TabWaveBackground()
                .environment(\.tabHeroStartLineInset, heroFrame.map(TabHeroStartLine.inset(for:)))
        }
        .sheet(isPresented: $isShowingComparison) {
            MetricComparisonView(metrics: comparisonMetrics)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingComparison = true
                } label: {
                    Label("Compare Metrics", systemImage: "chart.xyaxis.line")
                }
                .disabled(comparisonMetrics.count < 2)
                .accessibilityIdentifier("wellness-compare-metrics")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        openBodyRecord()
                    } label: {
                        Label("Body Record", systemImage: "figure.stand")
                    }
                    .accessibilityIdentifier("wellness-menu-body-record")
                    Button {
                        startAddingInjury()
                    } label: {
                        Label("Injury", systemImage: "bandage.fill")
                    }
                    .accessibilityIdentifier("wellness-menu-injury")
                    Button {
                        isShowingPostureCapture = true
                    } label: {
                        Label("Posture Assessment", systemImage: "figure.stand")
                    }
                    .accessibilityIdentifier("wellness-menu-posture")
                    Button {
                        isShowingRealtimePosture = true
                    } label: {
                        Label(String(localized: "Realtime Analysis"), systemImage: "figure.walk.motion")
                    }
                    .accessibilityIdentifier("wellness-menu-realtime-posture")
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
                    if let draft = bodyViewModel.createValidatedDraft() {
                        let record = draft.makeRecord()
                        do {
                            try await BodyCompositionWriteService().save(
                                recordID: record.id,
                                input: draft.writeInput
                            )
                        } catch {
                            bodyViewModel.validationError = String(localized: "Failed to save record changes. Please try again.")
                            bodyViewModel.didFinishSaving()
                            return false
                        }

                        modelContext.insert(record)
                        bodyViewModel.didFinishSaving()
                        bodyViewModel.resetForm()
                        bodyViewModel.isShowingAddSheet = false
                        viewModel.loadData()
                        return true
                    }
                    return false
                }
            )
        }
        .sheet(isPresented: $bodyViewModel.isShowingEditSheet) {
            if let record = bodyViewModel.editingRecord {
                BodyCompositionFormSheet(
                    viewModel: bodyViewModel,
                    isEdit: true,
                    onSave: {
                        let previousInput = BodyCompositionWriteInput(record: record)
                        guard let draft = bodyViewModel.createValidatedDraft() else {
                            return false
                        }
                        do {
                            try await BodyCompositionWriteService().update(
                                recordID: record.id,
                                previousInput: previousInput,
                                input: draft.writeInput
                            )
                            try modelContext.transaction {
                                bodyViewModel.apply(draft, to: record)
                            }
                            bodyViewModel.didFinishSaving()
                            bodyViewModel.isShowingEditSheet = false
                            bodyViewModel.editingRecord = nil
                            viewModel.loadData()
                            return true
                        } catch {
                            bodyViewModel.validationError = String(localized: "Failed to save record changes. Please try again.")
                            bodyViewModel.didFinishSaving()
                        }
                        return false
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
        #if !os(visionOS)
        .fullScreenCover(isPresented: $isShowingPostureCapture) {
            PostureCaptureView()
        }
        .fullScreenCover(isPresented: $isShowingRealtimePosture) {
            RealtimePostureView()
        }
        #endif
        // Correction #48: navigationDestination outside conditional blocks
        .navigationDestination(for: HealthMetric.self) { metric in
            MetricDetailView(metric: metric)
        }
        .navigationDestination(for: AllDataDestination.self) { destination in
            AllDataView(category: destination.category)
        }
        .navigationDestination(for: BodyHistoryDestination.self) { _ in
            BodyHistoryDetailView(
                viewModel: bodyViewModel,
                onRecordsChanged: { viewModel.loadData() }
            )
        }
        .navigationDestination(for: InjuryHistoryDestination.self) { _ in
            InjuryHistoryView(viewModel: injuryViewModel)
        }
        .navigationDestination(for: PostureHistoryDestination.self) { _ in
            PostureHistoryView()
        }
        .navigationDestination(for: PostureRecordDestination.self) { destination in
            PostureRecordLookupView(recordID: destination.id)
        }
        .navigationDestination(for: WellnessScoreDestination.self) { _ in
            if let score = viewModel.wellnessScore {
                WellnessScoreDetailView(
                    wellnessScore: score,
                    conditionScore: viewModel.conditionScoreFull,
                    bodyScoreDetail: viewModel.bodyScoreDetail,
                    scoreRefreshService: scoreRefreshService
                )
            } else {
                ProgressView()
            }
        }
        .navigationDestination(for: SleepPredictionDestination.self) { _ in
            if let prediction = viewModel.sleepPrediction {
                SleepPredictionDetailView(prediction: prediction)
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
        .onAppear {
            openWeightEntryIfNeeded(openWeightEntrySignal)
        }
        .onChange(of: openWeightEntrySignal) { _, signal in
            openWeightEntryIfNeeded(signal)
        }
        .englishNavigationTitle("Wellness")
    }

    // MARK: - Helpers

    private func openWeightEntryIfNeeded(_ signal: Int) {
        guard signal > lastHandledWeightEntrySignal else { return }
        lastHandledWeightEntrySignal = signal
        bodyViewModel.resetForm()
        bodyViewModel.isShowingAddSheet = true
    }

    private func flowPair<Leading: View, Trailing: View>(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        let layout = isRegular && !dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(HStackLayout(alignment: .top, spacing: DS.Spacing.lg))
            : AnyLayout(VStackLayout(spacing: DS.Spacing.lg))
        return layout {
            leading().frame(maxWidth: .infinity, alignment: .topLeading)
            trailing().frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var healthIndicatorsSection: some View {
        let order: [HealthMetric.Category] = [
            .hrv, .rhr, .heartRate, .spo2, .respiratoryRate, .wristTemperature,
            .vo2Max, .heartRateRecovery
        ]
        let cards = viewModel.activeCards.filter { $0.category != .sleep }.sorted { left, right in
            if left.isStale != right.isStale { return !left.isStale }
            return (order.firstIndex(of: left.category) ?? order.count)
                < (order.firstIndex(of: right.category) ?? order.count)
        }
        let primary = cards.filter { $0.category != .vo2Max && $0.category != .heartRateRecovery }
        let fitness = cards.filter { $0.category == .vo2Max || $0.category == .heartRateRecovery }
        if !cards.isEmpty {
            SectionGroup(
                title: "Health Indicators",
                icon: "heart.text.square",
                iconColor: DS.Color.vitals,
                sectionIdentifier: "wellness-section-health-indicators"
            ) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    healthMetricGrid(cards: primary)
                    if !fitness.isEmpty {
                        DisclosureGroup("Cardio Fitness and Heart Rate Recovery") {
                            healthMetricGrid(cards: fitness)
                                .padding(.top, DS.Spacing.sm)
                        }
                        .font(.caption.weight(.medium))
                        .tint(theme.accentColor)
                        .accessibilityIdentifier("wellness-fitness-disclosure")
                    }
                }
            }
        }
    }

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

    /// Eager rows keep SwiftData observations from feeding lazy scroll layout changes.
    private func healthMetricGrid(cards: [VitalCardData]) -> some View {
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        let rows = stride(from: 0, to: cards.count, by: columns).map { index in
            (id: cards[index].id, cards: Array(cards[index..<min(index + columns, cards.count)]))
        }
        return VStack(spacing: DS.Spacing.sm) {
            ForEach(rows, id: \.id) { row in
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    ForEach(row.cards) { card in
                        NavigationLink(value: card.metric) {
                            WellnessMetricCard(data: card)
                        }
                        .buttonStyle(CardNavigationButtonStyle())
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    if row.cards.count < columns {
                        Color.clear.frame(maxWidth: .infinity)
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
struct PostureHistoryDestination: Hashable {}
struct SleepPredictionDestination: Hashable {}

// MARK: - Isolated @Query Child Views
// Extracted to prevent SwiftData observation from triggering parent ScrollView re-layout.

/// Injury banner with its own @Query — re-renders independently of WellnessView body.
private struct WellnessInjuryBannerView: View {
    @Query(sort: \InjuryRecord.startDate, order: .reverse) private var injuryRecords: [InjuryRecord]
    @Environment(\.appTheme) private var theme

    enum Placement { case active, history }

    let placement: Placement
    let onEdit: (InjuryRecord) -> Void
    let onAdd: () -> Void

    var body: some View {
        let activeInjuries = injuryRecords.filter(\.isActive)
        if (placement == .active) == !activeInjuries.isEmpty {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if !injuryRecords.isEmpty {
                    NavigationLink(value: InjuryHistoryDestination()) {
                        CardNavigationHeader {
                            Label("Injuries", systemImage: "bandage.fill")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .buttonStyle(CardNavigationButtonStyle())
                    .accessibilityIdentifier("wellness-link-injuryhistory")
                    .accessibilityHint("View All")
                } else {
                    Label("Injuries", systemImage: "bandage.fill")
                        .font(.subheadline.weight(.semibold))
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
}

/// Posture assessment card with its own @Query — shows latest result or start prompt.
private struct PostureAssessmentLinkView: View {
    @Query(sort: \PostureAssessmentRecord.date, order: .reverse)
    private var records: [PostureAssessmentRecord]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var scoreDiameter: CGFloat = 40

    let onCapture: () -> Void
    let onRealtime: () -> Void
    var onScoreUpdate: ((Int?) -> Void)?

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                if !records.isEmpty {
                    NavigationLink(value: PostureHistoryDestination()) {
                        CardNavigationHeader {
                            Label("Posture Assessment", systemImage: "viewfinder")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .buttonStyle(CardNavigationButtonStyle())
                    .accessibilityIdentifier("wellness-link-posturehistory")
                    .accessibilityHint("View All")
                } else {
                    Label("Posture Assessment", systemImage: "viewfinder")
                        .font(.subheadline.weight(.semibold))
                }

                if let latest = records.first {
                    NavigationLink(value: PostureRecordDestination(id: latest.id)) {
                        assessmentSummary(latest)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(CardNavigationButtonStyle())
                    .accessibilityIdentifier("wellness-posture-record-\(latest.id.uuidString)")
                } else {
                    assessmentSummary(nil)
                }

                Label("Photo assessments and Watch records are shown separately.", systemImage: "viewfinder")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                actionButtons

                ForEach(records.dropFirst().prefix(2)) { record in
                    NavigationLink(value: PostureRecordDestination(id: record.id)) {
                        recordRow(record)
                    }
                    .buttonStyle(CardNavigationButtonStyle())
                    .accessibilityIdentifier("wellness-posture-record-\(record.id.uuidString)")
                }
            }
        }
        .task(id: latestScoreIdentity) {
            let measured = records.first?.allMetrics.contains { $0.status != .unmeasurable } ?? false
            onScoreUpdate?(measured ? records.first?.overallScore : nil)
        }
    }

    private var latestScoreIdentity: Int {
        var hasher = Hasher()
        hasher.combine(records.first?.id)
        hasher.combine(records.first?.overallScore)
        hasher.combine(records.first?.frontMetricsJSON)
        hasher.combine(records.first?.sideMetricsJSON)
        return hasher.finalize()
    }

    private func assessmentSummary(_ record: PostureAssessmentRecord?) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DS.Spacing.lg))
        return layout {
            if !dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 48, weight: .ultraLight))
                        .frame(width: 72, height: 84)
                        .background(DS.Color.body.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    Text("Front and side capture guide")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DS.Spacing.md)
                .frame(width: 112)
                .foregroundStyle(DS.Color.body)
                .background(DS.Color.body.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.lg))
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if let record {
                    Text(record.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                    if record.allMetrics.contains(where: { $0.status != .unmeasurable }) {
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                            Text(record.overallScore.formatted())
                                .font(.largeTitle.weight(.semibold).monospacedDigit())
                                .accessibilityIdentifier("wellness-posture-score")
                            Text(verbatim: "/100")
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                        GeometryReader { geometry in
                            Capsule().fill(DS.Color.body.opacity(0.12))
                                .overlay(alignment: .leading) {
                                    Capsule().fill(DS.Color.body)
                                        .frame(width: geometry.size.width * CGFloat(max(0, min(100, record.overallScore))) / 100)
                                }
                        }
                        .frame(height: 7)
                        .accessibilityHidden(true)
                    } else {
                        Text("Unable to measure")
                            .font(.headline)
                    }
                    Text("Photo assessment")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                } else {
                    Text("Record your posture")
                        .font(.headline)
                    Text("Use a photo or realtime analysis to get started.")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DS.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
        return layout {
            Button {
                onCapture()
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                    Text("Capture")
                        .font(.caption.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(DS.Color.body.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .buttonStyle(.plain)
            .tint(DS.Color.body)
            .accessibilityIdentifier("wellness-button-posture-capture")

            Button {
                onRealtime()
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "figure.walk.motion")
                        .font(.caption)
                    Text("Realtime")
                        .font(.caption.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(DS.Color.body.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .buttonStyle(.plain)
            .tint(DS.Color.body)
            .accessibilityIdentifier("wellness-button-posture-realtime")
        }
    }

    // MARK: - Record Row

    private func recordRow(_ record: PostureAssessmentRecord) -> some View {
        InlineCard {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
                : AnyLayout(HStackLayout(spacing: DS.Spacing.md))
            layout {
                if record.allMetrics.contains(where: { $0.status != .unmeasurable }) {
                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 4)
                        .frame(width: scoreDiameter, height: scoreDiameter)

                    Circle()
                        .trim(from: 0, to: CGFloat(record.overallScore) / 100.0)
                        .stroke(
                            scoreColor(record.overallScore),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: scoreDiameter, height: scoreDiameter)
                        .rotationEffect(.degrees(-90))

                    Text("\(record.overallScore)")
                        .font(.caption2.bold())
                }
                .frame(width: scoreDiameter, height: scoreDiameter)

                } else {
                    Text("Unable to measure")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    CardNavigationHeader(minimumHeight: 0) {
                        Text(record.date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.caption)
                            .fontWeight(.medium)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(String(localized: "\(record.allMetrics.filter { $0.status != .unmeasurable }.count) metrics measured"))
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        postureScoreColor(score)
    }
}

/// Lookup wrapper that resolves a PostureAssessmentRecord by ID via @Query.
private struct PostureRecordLookupView: View {
    let recordID: UUID
    @Query(sort: \PostureAssessmentRecord.date, order: .reverse)
    private var records: [PostureAssessmentRecord]

    var body: some View {
        if let record = records.first(where: { $0.id == recordID }) {
            PostureDetailView(record: record)
        } else {
            ContentUnavailableView("Record not found", systemImage: "exclamationmark.triangle")
        }
    }
}

#Preview {
    NavigationStack {
        WellnessView()
    }
    .modelContainer(for: [BodyCompositionRecord.self, InjuryRecord.self], inMemory: true)
}
