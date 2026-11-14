import Foundation

/// Separates saved measurement text for display without reinterpreting its values.
struct NotificationMessageContent {
    private static let measurementValue = try! NSRegularExpression(
        pattern: #"^\p{Nd}+(?:[.,]\p{Nd}+)*(?:\s*(?:kg|lbs?|%))?(?:\s*\([+\-−]?\p{Nd}+(?:[.,]\p{Nd}+)*(?:\s*(?:kg|lbs?|%))?\))?$"#
    )

    struct Measurement: Equatable {
        let label: String
        let value: String
    }

    let measurements: [Measurement]

    init(message: String, insightType: HealthInsight.InsightType) {
        guard [.weightUpdate, .bodyFatUpdate, .bmiUpdate].contains(insightType) else {
            measurements = []
            return
        }

        let lines = message.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        guard (1...3).contains(lines.count) else {
            measurements = []
            return
        }

        var parsed: [Measurement] = []
        for line in lines {
            guard let separator = line.firstIndex(where: { $0 == ":" || $0 == "：" }) else {
                measurements = []
                return
            }
            let label = line[..<separator].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            let valueRange = NSRange(value.startIndex..<value.endIndex, in: value)
            guard !label.isEmpty,
                  Self.measurementValue.firstMatch(in: value, range: valueRange) != nil else {
                measurements = []
                return
            }
            parsed.append(Measurement(label: label, value: value))
        }
        measurements = parsed
    }
}
