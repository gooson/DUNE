import Foundation
import Testing
@testable import DUNE

@Suite("NotificationMessageContent")
struct NotificationMessageContentTests {
    @Test("Keeps saved measurement order, precision and units", arguments: [
        HealthInsight.InsightType.weightUpdate, .bodyFatUpdate, .bmiUpdate
    ])
    func bodyComposition(type: HealthInsight.InsightType) {
        let content = NotificationMessageContent(message: "BMI: 24.9\nBody fat: 23.5%", insightType: type)
        #expect(content.measurements == [
            .init(label: "BMI", value: "24.9"),
            .init(label: "Body fat", value: "23.5%")
        ])
    }

    @Test("Preserves localized labels, decimal separators and weight change", arguments: [
        "BMI: 24.9\n체지방: 23.5%",
        "BMI：24,9\r\n体脂肪率：23,5%",
        "Weight: 75.0 kg (+0.5 kg)\nBMI: 24.9\nBody fat: 23.5%"
    ])
    func localizedMeasurements(message: String) {
        let content = NotificationMessageContent(message: message, insightType: .bmiUpdate)
        #expect(!content.measurements.isEmpty)
        #expect(content.measurements.map { "\($0.label): \($0.value)" }.joined(separator: "\n")
            == message.replacingOccurrences(of: "：", with: ": ").replacingOccurrences(of: "\r\n", with: "\n"))
    }

    @Test("Keeps the whole original body when any line cannot become a measurement", arguments: [
        "", "\n ", "BMI 24.9", "BMI:", ": 24.9", "BMI: --", "BMI: NaN",
        "BMI: 24.9\nA note about this measurement.",
        "BMI: 24.9\nBody fat: unavailable",
        "BMI: 24.9\nNote: 2026 was unusual",
        "BMI: 24.9\n\nBody fat: 23.5%",
        "\nBMI: 24.9\n",
        "One: 1\nTwo: 2\nThree: 3\nFour: 4"
    ])
    func fallsBackToOriginal(message: String) {
        #expect(NotificationMessageContent(message: message, insightType: .bmiUpdate).measurements.isEmpty)
    }

    @Test("A non-body notification keeps its original prose", arguments: [
        HealthInsight.InsightType.stepGoal, .sleepComplete, .hrvAnomaly, .dailyDigest
    ])
    func ordinaryMessage(type: HealthInsight.InsightType) {
        #expect(NotificationMessageContent(message: "Steps: 9800", insightType: type).measurements.isEmpty)
    }

    @Test("Single and repeated labels remain complete and retain their positions")
    func singleAndDuplicateLabels() {
        #expect(NotificationMessageContent(message: "BMI: 24.90", insightType: .bmiUpdate)
            .measurements == [.init(label: "BMI", value: "24.90")])
        #expect(NotificationMessageContent(message: "BMI: 24.9\nBMI: 25.0", insightType: .bmiUpdate)
            .measurements.map(\.value) == ["24.9", "25.0"])
    }
}
