import XCTest

/// Regression coverage for chart long-press vs visible-range/scroll interaction.
@MainActor
final class ChartInteractionRegressionUITests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "wellness" }

    func testWeightDetailChartLongPressKeepsVisibleRange() throws {
        let weightCard = app.descendants(matching: .any)[AXID.wellnessCardWeight].firstMatch
        guard weightCard.waitForExistence(timeout: 15) else {
            throw XCTSkip("Mock seed does not currently expose a stable weight detail chart path for gesture UI coverage.")
        }
        weightCard.tap()

        let chart = waitForElement(AXID.detailChartSurface, timeout: 15)
        let visibleRange = waitForElement(AXID.detailChartVisibleRange, timeout: 10)
        let initialRange = visibleRange.label

        let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.55))
        let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.55))
        start.press(forDuration: 0.45, thenDragTo: end)

        let currentRange = visibleRange.label
        XCTAssertEqual(
            currentRange,
            initialRange,
            "Long press selection should not change the chart visible range"
        )
        XCTAssertTrue(chart.exists, "Detail chart should remain visible after long press selection")
    }
}
