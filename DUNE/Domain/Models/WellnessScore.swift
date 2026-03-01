import Foundation

struct WellnessScore: Sendable, Hashable {
    let score: Int
    let status: Status
    let sleepScore: Int?
    let conditionScore: Int?
    let bodyScore: Int?
    let guideMessage: String

    enum Status: String, Sendable, CaseIterable {
        case excellent
        case good
        case fair
        case tired
        case warning
    }

    init(score: Int, sleepScore: Int? = nil, conditionScore: Int? = nil, bodyScore: Int? = nil) {
        self.score = max(0, min(100, score))
        self.sleepScore = sleepScore
        self.conditionScore = conditionScore
        self.bodyScore = bodyScore

        switch self.score {
        case 80...100: self.status = .excellent
        case 60...79: self.status = .good
        case 40...59: self.status = .fair
        case 20...39: self.status = .tired
        default: self.status = .warning
        }

        self.guideMessage = Self.message(for: self.status)
    }

    /// Data-driven narrative using sub-score breakdown.
    var narrativeMessage: String {
        let scores: [(String, Int)] = [
            (String(localized: "sleep"), sleepScore),
            (String(localized: "condition"), conditionScore),
            (String(localized: "body"), bodyScore)
        ].compactMap { name, val in
            guard let val else { return nil }
            return (name, val)
        }
        guard !scores.isEmpty else { return guideMessage }
        if let weakest = scores.min(by: { $0.1 < $1.1 }),
           let strongest = scores.max(by: { $0.1 < $1.1 }),
           strongest.1 - weakest.1 > 20 {
            return String(localized: "\(strongest.0.capitalized) is strong — \(weakest.0) needs attention")
        }
        return guideMessage
    }

    private static func message(for status: Status) -> String {
        switch status {
        case .excellent: String(localized: "Well recovered. Ready for high intensity.")
        case .good: String(localized: "Good condition. Normal training is fine.")
        case .fair: String(localized: "Some recovery needed. Consider lighter work.")
        case .tired: String(localized: "You need more rest. Low intensity only.")
        case .warning: String(localized: "Rest is recommended. Skip training today.")
        }
    }
}
