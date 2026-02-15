import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    if viewModel.isLoading && viewModel.conditionScore == nil && viewModel.sortedMetrics.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if viewModel.conditionScore == nil && viewModel.sortedMetrics.isEmpty && !viewModel.isLoading {
                        EmptyStateView(
                            icon: "heart.text.clipboard",
                            title: "No Health Data",
                            message: "Grant HealthKit access to see your condition score and daily metrics."
                        )
                    } else {
                        // Hero Section
                        if let score = viewModel.conditionScore {
                            ConditionHeroView(
                                score: score,
                                recentScores: viewModel.recentScores
                            )
                        } else if let status = viewModel.baselineStatus, !status.isReady {
                            BaselineProgressView(status: status)
                        }

                        // Metric Cards (smart sorted)
                        SmartCardGrid(metrics: viewModel.sortedMetrics)

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    }
                }
                .padding()
            }
            .background {
                LinearGradient(
                    colors: [DS.Color.hrv.opacity(0.03), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }
            .navigationTitle("Dailve")
            .refreshable {
                await viewModel.loadData()
            }
            .task {
                await viewModel.loadData()
            }
        }
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
