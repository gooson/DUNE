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

    private static func message(for status: Status) -> String {
        switch status {
        case .excellent: "Well recovered. Ready for high intensity."
        case .good: "Good condition. Normal training is fine."
        case .fair: "Some recovery needed. Consider lighter work."
        case .tired: "You need more rest. Low intensity only."
        case .warning: "Rest is recommended. Skip training today."
        }
    }
}
