import Foundation
import Testing
@testable import DUNE

@Suite("Metric detail value formatter")
struct MetricDetailValueFormatterTests {
    @Test("Each metric keeps its original headline precision",
          arguments: HealthMetric.Category.allCases)
    func categoryPrecision(category: HealthMetric.Category) {
        let value: Double
        let expected: String
        switch category {
        case .hrv, .rhr, .heartRate, .exercise, .steps, .respiratoryRate, .heartRateRecovery:
            value = 42.4
            expected = "42"
        case .sleep:
            value = 474
            expected = value.hoursMinutesFormatted
        case .weight, .bmi, .bodyFat, .leanBodyMass, .vo2Max, .breathingDisturbances:
            // Check precision without asserting a new policy for halfway rounding.
            value = 42.46
            expected = "42.5"
        case .spo2:
            value = 0.98
            expected = "98"
        case .wristTemperature:
            value = -0.3
            expected = "-0.3"
        }
        #expect(MetricDetailValueFormatter(category: category).string(from: value) == expected)
    }

    @Test("Workout headline honors its own metres or kilometres")
    func workoutDistanceUnits() {
        #expect(MetricDetailValueFormatter(category: .exercise, unitOverride: "m").string(from: 1314) == "1,314")
        #expect(MetricDetailValueFormatter(category: .exercise, unitOverride: "km").string(from: 1.314) == "1.3")
        #expect(MetricDetailValueFormatter(category: .exercise, unitOverride: "min").string(from: 42) == "42")
    }

    @Test("Invalid quantities never become plausible readings")
    func nonfiniteAndOverflow() {
        #expect(MetricDetailValueFormatter(category: .spo2).string(from: .infinity) == "—")
        #expect(MetricDetailValueFormatter(category: .spo2).string(from: .greatestFiniteMagnitude) == "—")
        #expect(MetricDetailValueFormatter(category: .sleep).string(from: Double(Int.max)) == "—")
    }
}
