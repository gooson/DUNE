import SwiftUI
import Charts

/// Container view for 3D chart navigation on visionOS.
/// Provides a picker to switch between different 3D chart types.
struct Chart3DContainerView: View {
    let sharedHealthDataService: SharedHealthDataService?
    var workoutService: WorkoutQuerying?

    @State private var selectedChart: Chart3DType = .conditionScatter
    @State private var refreshToken = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Chart Type", selection: $selectedChart) {
                    ForEach(Chart3DType.allCases) { chartType in
                        Text(chartType.displayName).tag(chartType)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                chartContent
                .id("\(selectedChart.rawValue)-\(refreshToken)")
            }
            .navigationTitle("3D Health Charts")
        }
        .onReceive(NotificationCenter.default.publisher(for: .simulatorAdvancedMockDataDidChange)) { _ in
            refreshToken += 1
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        switch selectedChart {
        case .conditionScatter:
            ConditionScatter3DView(sharedHealthDataService: sharedHealthDataService)
        case .trainingVolume:
            TrainingVolume3DView(workoutService: workoutService)
        }
    }
}

enum Chart3DType: String, CaseIterable, Identifiable {
    case conditionScatter
    case trainingVolume

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .conditionScatter: String(localized: "Condition")
        case .trainingVolume: String(localized: "Training")
        }
    }
}
