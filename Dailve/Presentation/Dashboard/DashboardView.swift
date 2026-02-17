import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.xl) {
                if viewModel.isLoading && viewModel.conditionScore == nil && viewModel.sortedMetrics.isEmpty {
                    DashboardSkeletonView()
                } else if viewModel.conditionScore == nil && viewModel.sortedMetrics.isEmpty && !viewModel.isLoading {
                    if viewModel.errorMessage != nil {
                        errorSection
                    } else {
                        EmptyStateView(
                            icon: "heart.text.clipboard",
                            title: "No Health Data",
                            message: "Grant HealthKit access to see your condition score and daily metrics.",
                            actionTitle: "Open Settings",
                            action: openSettings
                        )
                    }
                } else {
                    // Hero Section
                    if let score = viewModel.conditionScore {
                        NavigationLink(value: score) {
                            ConditionHeroView(
                                score: score,
                                recentScores: viewModel.recentScores
                            )
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.highlight)
                    } else if let status = viewModel.baselineStatus, !status.isReady {
                        BaselineProgressView(status: status)
                    }

                    // Last updated timestamp
                    if let lastUpdated = viewModel.lastUpdated {
                        Text("Updated \(lastUpdated, format: .relative(presentation: .named))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    // Score Contributors (Oura-style)
                    if let score = viewModel.conditionScore, !score.contributions.isEmpty {
                        ScoreContributorsView(contributions: score.contributions)
                    }

                    // Error banner (non-blocking — data may be partially loaded)
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }

                    // Health Signals section (HRV, RHR, Weight, BMI)
                    if !viewModel.healthSignals.isEmpty {
                        Section {
                            SmartCardGrid(metrics: viewModel.healthSignals)
                        } header: {
                            Text("Health Signals")
                                .font(DS.Typography.sectionTitle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !viewModel.activityMetrics.isEmpty {
                        Section {
                            SmartCardGrid(metrics: viewModel.activityMetrics)
                        } header: {
                            Text("Activity")
                                .font(DS.Typography.sectionTitle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.lg)
        }
        .background {
            LinearGradient(
                colors: [DS.Color.hrv.opacity(0.03), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .navigationDestination(for: ConditionScore.self) { score in
            ConditionScoreDetailView(score: score)
        }
        .navigationDestination(for: HealthMetric.self) { metric in
            MetricDetailView(metric: metric)
        }
        .navigationDestination(for: AllDataDestination.self) { destination in
            AllDataView(category: destination.category)
        }
        .refreshable {
            await viewModel.loadData()
        }
        .task {
            await viewModel.loadData()
        }
        .navigationTitle("Today")
    }

    // MARK: - Error States

    private var errorSection: some View {
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: "Something Went Wrong",
            message: viewModel.errorMessage ?? "An unexpected error occurred.",
            actionTitle: "Try Again",
            action: { Task { await viewModel.loadData() } }
        )
    }

    private func errorBanner(_ message: String) -> some View {
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
                    Task { await viewModel.loadData() }
                }
                .font(.caption)
                .fontWeight(.medium)
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - Baseline Progress

private struct BaselineProgressView: View {
    let status: BaselineStatus

    var body: some View {
        StandardCard {
            VStack(spacing: DS.Spacing.md) {
                Text("Establishing Baseline")
                    .font(.headline)

                ProgressView(value: status.progress)
                    .tint(DS.Color.hrv)

                Text("\(status.daysCollected)/\(status.daysRequired) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    DashboardView()
}
