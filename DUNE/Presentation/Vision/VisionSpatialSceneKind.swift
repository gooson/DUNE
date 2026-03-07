import SwiftUI

enum VisionSpatialSceneKind: String, CaseIterable, Identifiable {
    case heartRateOrb
    case trainingBlocks
    case bodyHeatmap

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .heartRateOrb:
            "Heart Orb"
        case .trainingBlocks:
            "Load Blocks"
        case .bodyHeatmap:
            "Body Heatmap"
        }
    }

    var description: LocalizedStringKey {
        switch self {
        case .heartRateOrb:
            "Pulsing sphere driven by your latest heart rate."
        case .trainingBlocks:
            "HealthKit-derived muscle workload as stacked blocks."
        case .bodyHeatmap:
            "Procedural body rig colored by recent fatigue."
        }
    }
}
