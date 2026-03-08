import Foundation

enum VisionSurfaceAccessibility {
    static let contentRoot = "vision-content-root"
    static let wellnessSleepSection = "vision-wellness-sleep-section"
    static let wellnessSleepEmptyState = "vision-wellness-sleep-empty-state"
    static let wellnessBodySection = "vision-wellness-body-section"
    static let wellnessBodyPlaceholder = "vision-wellness-body-placeholder"
    static let lifePlaceholder = "vision-life-placeholder"

    // MARK: - Chart3D Window
    static let chart3DRoot = "vision-chart3d-root"
    static let chart3DPicker = "vision-chart3d-picker"
    static let chart3DCondition = "vision-chart3d-condition"
    static let chart3DTraining = "vision-chart3d-training"

    static func sectionScreenID(for section: AppSection) -> String {
        "vision-content-screen-\(section.rawValue)"
    }
}
