import Foundation

struct ConditionScore: Sendable, Hashable {
    let score: Int
    let status: Status
    let date: Date
    let contributions: [ScoreContribution]

    static func == (lhs: ConditionScore, rhs: ConditionScore) -> Bool {
        lhs.score == rhs.score && lhs.date == rhs.date && lhs.contributions == rhs.contributions
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(score)
        hasher.combine(date)
        hasher.combine(contributions)
    }

    enum Status: String, Sendable, CaseIterable {
        case excellent
        case good
        case fair
        case tired
        case warning

        var label: String {
            switch self {
            case .excellent: "Excellent"
            case .good: "Good"
            case .fair: "Fair"
            case .tired: "Tired"
            case .warning: "Warning"
            }
        }

        var emoji: String {
            switch self {
            case .excellent: "\u{1F60A}"
            case .good: "\u{1F642}"
            case .fair: "\u{1F610}"
            case .tired: "\u{1F634}"
            case .warning: "\u{26A0}\u{FE0F}"
            }
        }

        var guideMessage: String {
            switch self {
            case .excellent: "You're in top shape"
            case .good: "Condition looks good"
            case .fair: "Take it easy today"
            case .tired: "You need more rest"
            case .warning: "Rest is recommended"
            }
        }
    }

    init(score: Int, date: Date = Date(), contributions: [ScoreContribution] = []) {
        self.score = max(0, min(100, score))
        self.date = date
        self.contributions = contributions
        switch self.score {
        case 80...100: self.status = .excellent
        case 60...79: self.status = .good
        case 40...59: self.status = .fair
        case 20...39: self.status = .tired
        default: self.status = .warning
        }
    }
}

struct BaselineStatus: Sendable {
    let daysCollected: Int
    let daysRequired: Int

    var isReady: Bool { daysCollected >= daysRequired }
    var progress: Double {
        guard daysRequired > 0 else { return 0 }
        return Double(daysCollected) / Double(daysRequired)
    }
}
