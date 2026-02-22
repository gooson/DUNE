import Foundation
import Testing
@testable import Dailve

@Suite("HealthMetric Model")
struct HealthMetricTests {
    @Test("changeSignificance returns abs value")
    func changeSignificance() {
        let positive = HealthMetric(id: "1", name: "Test", value: 50, unit: "ms", change: 5.0, date: Date(), category: .hrv)
        #expect(positive.changeSignificance == 5.0)

        let negative = HealthMetric(id: "2", name: "Test", value: 50, unit: "ms", change: -3.0, date: Date(), category: .hrv)
        #expect(negative.changeSignificance == 3.0)

        let noChange = HealthMetric(id: "3", name: "Test", value: 50, unit: "ms", change: nil, date: Date(), category: .hrv)
        #expect(noChange.changeSignificance == 0)
    }

    @Test("formattedValue formats correctly per category")
    func formattedValue() {
        let hrv = HealthMetric(id: "1", name: "HRV", value: 45.6, unit: "ms", change: nil, date: Date(), category: .hrv)
        #expect(hrv.formattedValue == "46 ms")

        let sleep = HealthMetric(id: "2", name: "Sleep", value: 450, unit: "min", change: nil, date: Date(), category: .sleep)
        #expect(sleep.formattedValue == "7h 30m")

        let steps = HealthMetric(id: "3", name: "Steps", value: 8500, unit: "", change: nil, date: Date(), category: .steps)
        #expect(steps.formattedValue == "8500 steps")
    }

    @Test("formattedChange returns nil when no change")
    func formattedChangeNil() {
        let metric = HealthMetric(id: "1", name: "Test", value: 50, unit: "ms", change: nil, date: Date(), category: .hrv)
        #expect(metric.formattedChange == nil)
    }

    @Test("formattedChange shows arrow direction")
    func formattedChangeArrow() {
        let up = HealthMetric(id: "1", name: "Test", value: 50, unit: "ms", change: 3.5, date: Date(), category: .hrv)
        #expect(up.formattedChange?.contains("\u{25B2}") == true)

        let down = HealthMetric(id: "2", name: "Test", value: 50, unit: "ms", change: -2.1, date: Date(), category: .hrv)
        #expect(down.formattedChange?.contains("\u{25BC}") == true)
    }

    @Test("isHistorical defaults to false")
    func isHistoricalDefault() {
        let metric = HealthMetric(id: "1", name: "Test", value: 50, unit: "ms", change: nil, date: Date(), category: .hrv)
        #expect(metric.isHistorical == false)
    }
}

@Suite("Date.relativeLabel")
struct DateRelativeLabelTests {
    @Test("Today returns nil")
    func todayReturnsNil() {
        #expect(Date().relativeLabel == nil)
    }

    @Test("Yesterday returns 'Yesterday'")
    func yesterdayLabel() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        #expect(yesterday.relativeLabel == "Yesterday")
    }

    @Test("3 days ago returns '3 days ago'")
    func threeDaysAgo() {
        let date = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        #expect(date.relativeLabel == "3 days ago")
    }

    @Test("freshnessLabel returns compact format")
    func freshnessLabelFormat() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        #expect(Date().freshnessLabel == "Today")
        #expect(threeDaysAgo.freshnessLabel == "3d ago")
    }
}
