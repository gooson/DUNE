import SwiftUI
import Charts

/// Container view for 3D chart navigation on visionOS.
/// Provides a picker to switch between different 3D chart types.
struct Chart3DContainerView: View {
    let sharedHealthDataService: SharedHealthDataService?

    @State private var selectedChart: Chart3DType = .conditionScatter

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

                switch selectedChart {
                case .conditionScatter:
                    ConditionScatter3DView()
                case .trainingVolume:
                    TrainingVolume3DView()
                }
            }
            .navigationTitle("3D Health Charts")
        }
    }
}

enum Chart3DType: String, CaseIterable, Identifiable {
    case conditionScatter
    case trainingVolume

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .conditionScatter: "Condition"
        case .trainingVolume: "Training"
        }
    }
}
