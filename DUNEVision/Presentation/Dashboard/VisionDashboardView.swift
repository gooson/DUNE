import SwiftUI

/// visionOS-optimized dashboard with glass material background.
/// Provides a spatial entry point to condition data, health metrics, and 3D charts.
struct VisionDashboardView: View {
    let sharedHealthDataService: SharedHealthDataService?
    let refreshSignal: Int
    let isSimulatorMockEnabled: Bool
    let simulatorMockStatusMessage: String?
    let onOpenSettings: () -> Void
    let onOpenDashboardWindow: (VisionDashboardWindowKind) -> Void
    let onOpen3DCharts: () -> Void
    let onOpenVolumetric: () -> Void
    let onOpenImmersive: () -> Void
    let onSeedAdvancedMockData: () -> Void
    let onResetAdvancedMockData: () -> Void

    @State private var snapshot: SharedHealthSnapshot?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                conditionSection
                quickActionsSection
                if SimulatorAdvancedMockDataModeStore.isSimulatorAvailable {
                    simulatorMockDataSection
                }
                healthMetricsSection
            }
            .padding(24)
        }
        .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardRoot)
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
                .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardToolbarSettings)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    onOpenImmersive()
                } label: {
                    Label("Immersive Space", systemImage: "sparkles")
                }
                .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardToolbarImmersive)

                Button {
                    onOpenVolumetric()
                } label: {
                    Label("Spatial Volume", systemImage: "cube.transparent")
                }
                .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardToolbarVolumetric)

                Button {
                    onOpen3DCharts()
                } label: {
                    Label("3D Charts", systemImage: "chart.bar.fill")
                }
                .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardToolbarChart3D)

                if SimulatorAdvancedMockDataModeStore.isSimulatorAvailable {
                    Menu {
                        Button("Seed Advanced Mock Data", action: onSeedAdvancedMockData)
                        Button("Reset Mock Data", role: .destructive, action: onResetAdvancedMockData)
                    } label: {
                        Label("Mock Data", systemImage: isSimulatorMockEnabled ? "shippingbox.fill" : "shippingbox")
                    }
                    .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardToolbarMockData)
                }
            }
        }
        .task(id: refreshSignal) {
            await loadData()
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let service = sharedHealthDataService else { return }
        snapshot = await service.fetchSnapshot()
    }

    // MARK: - Sections

    @ViewBuilder
    private var conditionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(verbatim: "CONDITION")
                .font(.headline)
                .foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .frame(height: 200)
                .overlay {
                    VStack(spacing: 8) {
                        Text(conditionScoreText)
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                        Text("Condition Score")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
        }
        .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardConditionSection)
    }

    @ViewBuilder
    private var quickActionsSection: some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]

        LazyVGrid(columns: columns, spacing: 16) {
            quickActionCard(
                title: "Condition",
                icon: VisionDashboardWindowKind.condition.systemImage,
                identifier: VisionSurfaceAccessibility.dashboardQuickActionID(for: .condition)
            ) {
                onOpenDashboardWindow(.condition)
            }

            quickActionCard(
                title: "Activity",
                icon: VisionDashboardWindowKind.activity.systemImage,
                identifier: VisionSurfaceAccessibility.dashboardQuickActionID(for: .activity)
            ) {
                onOpenDashboardWindow(.activity)
            }

            quickActionCard(
                title: "Sleep",
                icon: VisionDashboardWindowKind.sleep.systemImage,
                identifier: VisionSurfaceAccessibility.dashboardQuickActionID(for: .sleep)
            ) {
                onOpenDashboardWindow(.sleep)
            }

            quickActionCard(
                title: "Body",
                icon: VisionDashboardWindowKind.body.systemImage,
                identifier: VisionSurfaceAccessibility.dashboardQuickActionID(for: .body)
            ) {
                onOpenDashboardWindow(.body)
            }
        }
        .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardQuickActionsSection)
    }

    @ViewBuilder
    private var healthMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Metrics")
                .font(.headline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 16) {
                metricCard(
                    title: "HRV",
                    value: hrvText,
                    unit: "ms",
                    icon: "waveform.path.ecg",
                    identifier: VisionSurfaceAccessibility.dashboardMetricHRV
                )
                metricCard(
                    title: "RHR",
                    value: rhrText,
                    unit: "bpm",
                    icon: "heart.fill",
                    identifier: VisionSurfaceAccessibility.dashboardMetricRHR
                )
                metricCard(
                    title: "Sleep",
                    value: sleepText,
                    unit: "hrs",
                    icon: "moon.fill",
                    identifier: VisionSurfaceAccessibility.dashboardMetricSleep
                )
            }
        }
        .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardHealthMetricsSection)
    }

    @ViewBuilder
    private var simulatorMockDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mock Data")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 14) {
                Image(systemName: isSimulatorMockEnabled ? "checkmark.circle.fill" : "shippingbox")
                    .font(.title2)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Advanced Athlete")
                        .font(.headline)
                    Text("Simulator only. Seeds advanced athlete health trends, workouts, and per-exercise history.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if let simulatorMockStatusMessage {
                Text(verbatim: simulatorMockStatusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityIdentifier(VisionSurfaceAccessibility.dashboardMockDataSection)
    }

    // MARK: - Computed Display Values

    private var conditionScoreText: String {
        guard let score = snapshot?.conditionScore?.score else { return "--" }
        return "\(score)"
    }

    private var hrvText: String {
        guard let latest = snapshot?.hrvSamples14Day.first else { return "--" }
        return String(format: "%.0f", latest.value)
    }

    private var rhrText: String {
        guard let rhr = snapshot?.effectiveRHR else { return "--" }
        return String(format: "%.0f", rhr.value)
    }

    private var sleepText: String {
        guard let summary = snapshot?.sleepSummaryForRecovery else { return "--" }
        let hours = summary.totalSleepMinutes / 60.0
        return String(format: "%.1f", hours)
    }

    // MARK: - Components

    @ViewBuilder
    private func quickActionCard(
        title: LocalizedStringKey,
        icon: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 160)
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func metricCard(
        title: LocalizedStringKey,
        value: String,
        unit: String,
        icon: String,
        identifier: String
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
            Text(value)
                .font(.title2.bold())
            HStack(spacing: 2) {
                Text(title)
                if !unit.isEmpty {
                    Text(unit)
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier(identifier)
    }
}
