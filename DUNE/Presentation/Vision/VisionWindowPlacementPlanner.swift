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

enum VisionWindowPlacementSmokeMode: Equatable, Sendable {
    case disabled
    case primary
    case noAnchor
}

struct VisionWindowPlacementSmokeConfiguration: Equatable, Sendable {
    static let smokeLaunchArgument = "--vision-window-placement-smoke"
    static let noAnchorSmokeLaunchArgument = "--vision-window-placement-no-anchor-smoke"
    static let seedMockLaunchArgument = "--seed-mock"

    let mode: VisionWindowPlacementSmokeMode
    let shouldSeedMockData: Bool
    let mainWindowAutoOpenIDs: [String]
    let secondaryWindowAutoOpenIDs: [String]
    let shouldDismissMainWindow: Bool

    var isEnabled: Bool {
        mode != .disabled
    }

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> VisionWindowPlacementSmokeConfiguration {
        let mode: VisionWindowPlacementSmokeMode
        if arguments.contains(noAnchorSmokeLaunchArgument) {
            mode = .noAnchor
        } else if arguments.contains(smokeLaunchArgument) {
            mode = .primary
        } else {
            mode = .disabled
        }

        let shouldSeedMockData = mode != .disabled || arguments.contains(seedMockLaunchArgument)

        let mainWindowAutoOpenIDs: [String]
        let secondaryWindowAutoOpenIDs: [String]
        let shouldDismissMainWindow: Bool

        switch mode {
        case .disabled:
            mainWindowAutoOpenIDs = []
            secondaryWindowAutoOpenIDs = []
            shouldDismissMainWindow = false
        case .primary:
            mainWindowAutoOpenIDs = [
                VisionDashboardWindowKind.condition.windowID,
                VisionDashboardWindowKind.activity.windowID,
                VisionDashboardWindowKind.sleep.windowID,
                VisionDashboardWindowKind.body.windowID,
                VisionWindowPlacementPlanner.chart3DWindowID,
            ]
            secondaryWindowAutoOpenIDs = []
            shouldDismissMainWindow = false
        case .noAnchor:
            mainWindowAutoOpenIDs = [VisionWindowPlacementPlanner.settingsWindowID]
            secondaryWindowAutoOpenIDs = [
                VisionWindowPlacementPlanner.chart3DWindowID,
                VisionDashboardWindowKind.condition.windowID,
            ]
            shouldDismissMainWindow = true
        }

        return VisionWindowPlacementSmokeConfiguration(
            mode: mode,
            shouldSeedMockData: shouldSeedMockData,
            mainWindowAutoOpenIDs: mainWindowAutoOpenIDs,
            secondaryWindowAutoOpenIDs: secondaryWindowAutoOpenIDs,
            shouldDismissMainWindow: shouldDismissMainWindow
        )
    }
}
