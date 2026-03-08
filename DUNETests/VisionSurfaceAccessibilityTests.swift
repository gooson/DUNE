import Testing
@testable import DUNE

@Suite("VisionSurfaceAccessibility")
struct VisionSurfaceAccessibilityTests {
    @Test("Section screen identifiers stay stable and unique")
    func sectionScreenIdentifiers() {
        let identifiers = AppSection.allCases.map(VisionSurfaceAccessibility.sectionScreenID)

        #expect(
            identifiers
                == [
                    "vision-content-screen-today",
                    "vision-content-screen-train",
                    "vision-content-screen-wellness",
                    "vision-content-screen-life",
                ]
        )
        #expect(Set(identifiers).count == AppSection.allCases.count)
    }

    @Test("Root and placeholder identifiers stay stable")
    func placeholderIdentifiers() {
        #expect(VisionSurfaceAccessibility.contentRoot == "vision-content-root")
        #expect(VisionSurfaceAccessibility.wellnessSleepSection == "vision-wellness-sleep-section")
        #expect(VisionSurfaceAccessibility.wellnessSleepEmptyState == "vision-wellness-sleep-empty-state")
        #expect(VisionSurfaceAccessibility.wellnessBodySection == "vision-wellness-body-section")
        #expect(VisionSurfaceAccessibility.wellnessBodyPlaceholder == "vision-wellness-body-placeholder")
        #expect(VisionSurfaceAccessibility.lifePlaceholder == "vision-life-placeholder")
    }
}
