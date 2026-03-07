import SwiftUI
import WidgetKit

/// Widget bundle for DUNE visionOS Spatial Widgets.
/// These widgets can be pinned to surfaces in the user's environment
/// for glanceable health data.
@main
struct DUNEVisionWidgetBundle: WidgetBundle {
    var body: some Widget {
        ConditionScoreWidget()
        TrainingReadinessWidget()
        SleepSummaryWidget()
    }
}
