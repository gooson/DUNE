import Foundation

enum VisionWindowPlacementRelationship: Equatable, Sendable {
    case utilityPanel
    case leading(String?)
    case trailing(String?)
    case above(String?)
    case below(String?)
}

enum VisionWindowPlacementPlanner {
    static let mainWindowID: String? = nil
    static let settingsWindowID = "settings"
    static let chart3DWindowID = "chart3d"

    static func relationship(
        for windowID: String,
        existingWindowIDs: Set<String?>
    ) -> VisionWindowPlacementRelationship {
        switch windowID {
        case VisionDashboardWindowKind.condition.windowID:
            guard existingWindowIDs.contains(mainWindowID) else {
                return .utilityPanel
            }
            return .leading(mainWindowID)

        case VisionDashboardWindowKind.activity.windowID:
            guard existingWindowIDs.contains(mainWindowID) else {
                return .utilityPanel
            }
            return .trailing(mainWindowID)

        case VisionDashboardWindowKind.sleep.windowID:
            if existingWindowIDs.contains(VisionDashboardWindowKind.condition.windowID) {
                return .below(VisionDashboardWindowKind.condition.windowID)
            }
            guard existingWindowIDs.contains(mainWindowID) else {
                return .utilityPanel
            }
            return .below(mainWindowID)

        case VisionDashboardWindowKind.body.windowID:
            if existingWindowIDs.contains(VisionDashboardWindowKind.activity.windowID) {
                return .below(VisionDashboardWindowKind.activity.windowID)
            }
            guard existingWindowIDs.contains(mainWindowID) else {
                return .utilityPanel
            }
            return .below(mainWindowID)

        case settingsWindowID:
            return .utilityPanel

        case chart3DWindowID:
            guard existingWindowIDs.contains(mainWindowID) else {
                return .utilityPanel
            }
            return .above(mainWindowID)

        default:
            return .utilityPanel
        }
    }
}
