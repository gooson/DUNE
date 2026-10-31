import Foundation
import Testing
@testable import DUNE

@Suite("Exercise highlight value units")
struct ExerciseHighlightValueFormatterTests {
    @Test("Distance high rounds the chart's kilometre value")
    func highDistance() {
        #expect(ExerciseHighlightValueFormatter.string(from: 1.314, type: .high, resolvedChartUnit: "km") == "1.3 km")
    }

    @Test("Distance low keeps the same resolved unit")
    func lowDistance() {
        #expect(ExerciseHighlightValueFormatter.string(from: 10.2, type: .low, resolvedChartUnit: "km") == "10.2 km")
    }

    @Test("Duration high keeps the original minute presentation")
    func highDuration() {
        #expect(ExerciseHighlightValueFormatter.string(from: 38, type: .high, resolvedChartUnit: "min") == "38 min")
    }

    @Test("Positive and negative trends are already percentages")
    func trendPercent() {
        #expect(ExerciseHighlightValueFormatter.string(from: 12.3, type: .trend, resolvedChartUnit: "km") == "12.3%")
        #expect(ExerciseHighlightValueFormatter.string(from: -12.3, type: .trend, resolvedChartUnit: "min") == "-12.3%")
    }

    @Test("Optional unit preserves the historical duration default")
    func omittedUnit() {
        #expect(ExerciseHighlightValueFormatter.string(from: 38, type: .low) == "38 min")
    }
}
