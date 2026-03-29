import Testing
import UIKit
@testable import DUNE

@Suite("PRShareService")
@MainActor
struct PRShareServiceTests {

    private func sampleData(
        delta: String? = "+5.2",
        value: String = "142.5"
    ) -> PRShareData {
        PRShareData(
            exerciseName: "Bench Press",
            kindDisplayName: "Est. 1RM",
            kindIconName: "trophy.fill",
            formattedValue: value,
            unitLabel: "kg",
            formattedDelta: delta,
            date: Date()
        )
    }

    @Test("renders non-nil image with valid dimensions")
    func renderValidImage() {
        let data = sampleData()
        let image = PRShareService.renderShareImage(data: data, accentColor: .yellow)

        #expect(image != nil)
        if let image {
            #expect(image.size.width > 0)
            #expect(image.size.height > 0)
        }
    }

    @Test("measured size has valid width and height")
    func measuredSizeValid() {
        let data = sampleData()
        let size = PRShareService.measuredRenderSize(data: data, accentColor: .yellow)

        #expect(size.width > 0)
        #expect(size.height > 0)
        #expect(size.width >= PRShareService.renderWidth)
    }

    @Test("renders image without delta")
    func renderWithoutDelta() {
        let data = sampleData(delta: nil)
        let image = PRShareService.renderShareImage(data: data, accentColor: .orange)

        #expect(image != nil)
        if let image {
            #expect(image.size.width > 0)
            #expect(image.size.height > 0)
        }
    }

    @Test("builds share data from ActivityPersonalRecord")
    func buildShareData() {
        let record = ActivityPersonalRecord(
            id: "test-1",
            kind: .estimated1RM,
            title: "Bench Press",
            value: 142.5,
            date: Date(),
            isRecent: true,
            source: .manual,
            previousValue: 137.3
        )

        let data = PRShareService.buildShareData(from: record)

        #expect(data.exerciseName == record.localizedTitle)
        #expect(data.kindDisplayName == record.kind.displayName)
        #expect(data.kindIconName == record.kind.iconName)
        #expect(data.formattedValue == record.formattedValue)
        #expect(data.unitLabel == record.kind.unitLabel)
        #expect(data.formattedDelta == record.formattedDelta)
    }

    @Test("renders image for pace kind")
    func renderPaceKind() {
        let data = PRShareData(
            exerciseName: "Running",
            kindDisplayName: "Fastest Pace",
            kindIconName: "speedometer",
            formattedValue: "4'30\"",
            unitLabel: "/km",
            formattedDelta: nil,
            date: Date()
        )
        let image = PRShareService.renderShareImage(data: data, accentColor: .green)

        #expect(image != nil)
    }
}
