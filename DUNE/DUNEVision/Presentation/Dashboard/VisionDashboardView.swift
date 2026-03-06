import SwiftUI

/// visionOS-optimized dashboard with glass material background.
/// Provides a spatial entry point to condition data, health metrics, and 3D charts.
struct VisionDashboardView: View {
    let sharedHealthDataService: SharedHealthDataService?
    let refreshSignal: Int
    let onOpen3DCharts: () -> Void
    let onOpenVolumetric: () -> Void

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
                    onOpenVolumetric()
                } label: {
                    Label("Spatial Volume", systemImage: "cube.transparent")
                }

                Button {
                    onOpen3DCharts()
                } label: {
                    Label("3D Charts", systemImage: "chart.bar.3d.grouped")
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
        HStack(spacing: 16) {
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

            // TODO: Connect to workout logging navigation
            quickActionCard(
                title: "Log Workout",
                icon: "figure.strengthtraining.traditional",
                description: "Record your training session"
            ) {}
                .disabled(true)
                .opacity(0.5)

            // TODO: Connect to body composition navigation
            quickActionCard(
                title: "Body Stats",
                icon: "figure.stand",
                description: "View body composition trends"
            ) {}
                .disabled(true)
                .opacity(0.5)
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
        description: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func metricCard(title: String, value: String, unit: String, icon: String) -> some View {
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
