import Foundation

struct ConditionScore: Sendable {
    let score: Int
    let status: Status
    let date: Date

    enum Status: String, Sendable, CaseIterable {
        case excellent
        case good
        case fair
        case tired
        case warning

        var label: String {
            switch self {
            case .excellent: "매우 좋음"
            case .good: "좋음"
            case .fair: "보통"
            case .tired: "피로"
            case .warning: "주의"
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
    }

    init(score: Int, date: Date = Date()) {
        self.score = max(0, min(100, score))
        self.date = date
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
    var progress: Double { Double(daysCollected) / Double(daysRequired) }
}
