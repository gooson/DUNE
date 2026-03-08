import Foundation

enum VisionSurfaceAccessibility {
    static let contentRoot = "vision-content-root"
    static let wellnessSleepSection = "vision-wellness-sleep-section"
    static let wellnessSleepEmptyState = "vision-wellness-sleep-empty-state"
    static let wellnessBodySection = "vision-wellness-body-section"
    static let wellnessBodyPlaceholder = "vision-wellness-body-placeholder"
    static let lifePlaceholder = "vision-life-placeholder"

    static func sectionScreenID(for section: AppSection) -> String {
        "vision-content-screen-\(section.rawValue)"
    }
}
