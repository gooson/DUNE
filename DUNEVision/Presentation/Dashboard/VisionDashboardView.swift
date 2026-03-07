import SwiftUI

/// visionOS-optimized dashboard with glass material background.
/// Provides a spatial entry point to condition data, health metrics, and 3D charts.
struct VisionDashboardView: View {
    // TODO: Wire to condition/metrics display when Phase 4 (live data) lands
    let sharedHealthDataService: SharedHealthDataService?
    let refreshSignal: Int
    let onOpenDashboardWindow: (VisionDashboardWindowKind) -> Void
    let onOpen3DCharts: () -> Void
    let onOpenVolumetric: () -> Void
    let onOpenImmersive: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                conditionSection
                quickActionsSection
                healthMetricsSection
            }
            .padding(24)
        }
        .navigationTitle("Today")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    onOpenImmersive()
                } label: {
                    Label("Immersive Space", systemImage: "sparkles")
                }

                Button {
                    onOpenVolumetric()
                } label: {
                    Label("Spatial Volume", systemImage: "cube.transparent")
                }

                Button {
                    onOpen3DCharts()
                } label: {
                    Label("3D Charts", systemImage: "chart.bar.fill")
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var conditionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(verbatim: "CONDITION")
                .font(.headline)
                .foregroundStyle(.secondary)

            // Placeholder — will be connected to ConditionScore UseCase
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .frame(height: 200)
                .overlay {
                    VStack(spacing: 8) {
                        Text("--")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                        Text("Condition Score")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
        }
    }

    @ViewBuilder
    private var quickActionsSection: some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]

        LazyVGrid(columns: columns, spacing: 16) {
            quickActionCard(
                title: "Condition",
                icon: VisionDashboardWindowKind.condition.systemImage
            ) {
                onOpenDashboardWindow(.condition)
            }

            quickActionCard(
                title: "Activity",
                icon: VisionDashboardWindowKind.activity.systemImage
            ) {
                onOpenDashboardWindow(.activity)
            }

            quickActionCard(
                title: "Sleep",
                icon: VisionDashboardWindowKind.sleep.systemImage
            ) {
                onOpenDashboardWindow(.sleep)
            }

            quickActionCard(
                title: "Body",
                icon: VisionDashboardWindowKind.body.systemImage
            ) {
                onOpenDashboardWindow(.body)
            }

            quickActionCard(
                title: "Immersive Space",
                icon: "sparkles",
                description: "Open the condition, recovery, and sleep space"
            ) {
                onOpenImmersive()
            }

            quickActionCard(
                title: "Spatial Volume",
                icon: "cube.transparent",
                description: "Open the volumetric recovery scene"
            ) {
                onOpenVolumetric()
            }

            quickActionCard(
                title: "3D Health Data",
                icon: "cube.fill",
                description: "Explore your health metrics in 3D"
            ) {
                onOpen3DCharts()
            }
        }
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
                metricCard(title: "HRV", value: "--", unit: "ms", icon: "waveform.path.ecg")
                metricCard(title: "RHR", value: "--", unit: "bpm", icon: "heart.fill")
                metricCard(title: "Sleep", value: "--", unit: "hrs", icon: "moon.fill")
                metricCard(title: "Steps", value: "--", unit: "", icon: "figure.walk")
                metricCard(title: "Weight", value: "--", unit: "kg", icon: "scalemass.fill")
                metricCard(title: "Body Fat", value: "--", unit: "%", icon: "percent")
            }
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func quickActionCard(
        title: LocalizedStringKey,
        icon: String,
        description: LocalizedStringKey? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.headline)
                if let description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 132)
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func metricCard(title: LocalizedStringKey, value: String, unit: String, icon: String) -> some View {
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
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
