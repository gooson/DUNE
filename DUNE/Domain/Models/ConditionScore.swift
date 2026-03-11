import Foundation

struct ConditionScore: Sendable, Hashable {
    let score: Int
    let status: Status
    let date: Date
    let contributions: [ScoreContribution]
    let detail: ConditionScoreDetail?

    static func == (lhs: ConditionScore, rhs: ConditionScore) -> Bool {
        lhs.score == rhs.score && lhs.date == rhs.date && lhs.contributions == rhs.contributions && lhs.detail == rhs.detail
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(score)
        hasher.combine(date)
        hasher.combine(contributions)
        hasher.combine(detail)
    }

    enum Status: String, Sendable, CaseIterable {
        case excellent
        case good
        case fair
        case tired
        case warning

        var label: String {
            switch self {
            case .excellent: String(localized: "Excellent")
            case .good: String(localized: "Good")
            case .fair: String(localized: "Fair")
            case .tired: String(localized: "Tired")
            case .warning: String(localized: "Warning")
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
            case .excellent: String(localized: "You're in top shape")
            case .good: String(localized: "Condition looks good")
            case .fair: String(localized: "Take it easy today")
            case .tired: String(localized: "You need more rest")
            case .warning: String(localized: "Rest is recommended")
            }
        }
    }

    /// Data-driven narrative for hero card display.
    var narrativeMessage: String {
        guard let detail else { return status.guideMessage }
        let hrvAboveBaseline = detail.todayHRV >= detail.baselineHRV
        let elevatedRHR = (detail.rhrDeltaFromBaseline ?? 0) >= 2
        let lowerRHR = (detail.rhrDeltaFromBaseline ?? 0) <= -2
        switch status {
        case .excellent:
            if hrvAboveBaseline && lowerRHR {
                return String(localized: "Top shape — HRV up, RHR down")
            }
            if hrvAboveBaseline {
                return String(localized: "Top shape — HRV above baseline")
            }
            if lowerRHR {
                return String(localized: "Excellent recovery — RHR below baseline")
            }
            return String(localized: "Excellent recovery today")
        case .good:
            if elevatedRHR {
                return String(localized: "Good overall — RHR above baseline")
            }
            if lowerRHR {
                return String(localized: "Good recovery — RHR below baseline")
            }
            return String(localized: "Solid recovery — HRV looks stable")
        case .fair:
            if elevatedRHR {
                return String(localized: "Recovery dipped — RHR above baseline")
            }
            if !hrvAboveBaseline {
                return String(localized: "HRV below baseline — take it easy")
            }
            return String(localized: "Moderate recovery — lighter activity today")
        case .tired:
            if elevatedRHR {
                return String(localized: "RHR elevated and recovery low — rest recommended")
            }
            return String(localized: "HRV significantly low — rest recommended")
        case .warning:
            if elevatedRHR {
                return String(localized: "Recovery very low — elevated RHR suggests rest")
            }
            return String(localized: "Recovery very low — prioritize rest")
        }
    }

    init(score: Int, date: Date = Date(), contributions: [ScoreContribution] = [], detail: ConditionScoreDetail? = nil) {
        self.score = max(0, min(100, score))
        self.date = date
        self.contributions = contributions
        self.detail = detail
        switch self.score {
        case 80...100: self.status = .excellent
        case 60...79: self.status = .good
        case 40...59: self.status = .fair
        case 20...39: self.status = .tired
        default: self.status = .warning
        }
    }
}

// MARK: - Condition Score Computation Detail

struct ConditionScoreDetail: Sendable, Hashable, Codable {
    /// Today's daily average HRV in ms
    let todayHRV: Double
    /// Baseline average HRV in ms (exp of ln-mean)
    let baselineHRV: Double
    /// Z-score: (todayLn - baselineLn) / effectiveStdDev
    let zScore: Double
    /// Actual standard deviation in ln-space
    let stdDev: Double
    /// Effective std dev used: max(stdDev, minimumStdDev)
    let effectiveStdDev: Double
    /// Number of daily averages in baseline
    let daysInBaseline: Int
    /// Date of the "today" average (most recent day with data)
    let todayDate: Date
    /// Raw score before clamping to [0, 100]
    let rawScore: Double
    /// Signed RHR score adjustment. Positive values lift the score; negative values reduce it.
    let rhrAdjustment: Double
    /// Today's resting heart rate (bpm), nil if unavailable
    let todayRHR: Double?
    /// Yesterday's resting heart rate (bpm), nil if unavailable
    let yesterdayRHR: Double?
    /// Baseline resting heart rate used for scoring (bpm)
    let baselineRHR: Double?
    /// Difference between today's RHR and baseline (bpm)
    let rhrDeltaFromBaseline: Double?
    /// Number of baseline RHR days used for comparison
    let rhrBaselineDays: Int
    /// Effective RHR for display (may be from a recent day when todayRHR is nil)
    let displayRHR: Double?
    /// Date of the displayRHR value
    let displayRHRDate: Date?

    var rhrPenalty: Double {
        max(0, -rhrAdjustment)
    }

    init(
        todayHRV: Double,
        baselineHRV: Double,
        zScore: Double,
        stdDev: Double,
        effectiveStdDev: Double,
        daysInBaseline: Int,
        todayDate: Date,
        rawScore: Double,
        rhrAdjustment: Double = 0,
        todayRHR: Double? = nil,
        yesterdayRHR: Double? = nil,
        baselineRHR: Double? = nil,
        rhrDeltaFromBaseline: Double? = nil,
        rhrBaselineDays: Int = 0,
        displayRHR: Double? = nil,
        displayRHRDate: Date? = nil
    ) {
        self.todayHRV = todayHRV
        self.baselineHRV = baselineHRV
        self.zScore = zScore
        self.stdDev = stdDev
        self.effectiveStdDev = effectiveStdDev
        self.daysInBaseline = daysInBaseline
        self.todayDate = todayDate
        self.rawScore = rawScore
        self.rhrAdjustment = rhrAdjustment
        self.todayRHR = todayRHR
        self.yesterdayRHR = yesterdayRHR
        self.baselineRHR = baselineRHR
        self.rhrDeltaFromBaseline = rhrDeltaFromBaseline
        self.rhrBaselineDays = rhrBaselineDays
        self.displayRHR = displayRHR
        self.displayRHRDate = displayRHRDate
    }

    private enum CodingKeys: String, CodingKey {
        case todayHRV
        case baselineHRV
        case zScore
        case stdDev
        case effectiveStdDev
        case daysInBaseline
        case todayDate
        case rawScore
        case rhrAdjustment
        case rhrPenalty
        case todayRHR
        case yesterdayRHR
        case baselineRHR
        case rhrDeltaFromBaseline
        case rhrBaselineDays
        case displayRHR
        case displayRHRDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        todayHRV = try container.decode(Double.self, forKey: .todayHRV)
        baselineHRV = try container.decode(Double.self, forKey: .baselineHRV)
        zScore = try container.decode(Double.self, forKey: .zScore)
        stdDev = try container.decode(Double.self, forKey: .stdDev)
        effectiveStdDev = try container.decode(Double.self, forKey: .effectiveStdDev)
        daysInBaseline = try container.decode(Int.self, forKey: .daysInBaseline)
        todayDate = try container.decode(Date.self, forKey: .todayDate)
        rawScore = try container.decode(Double.self, forKey: .rawScore)
        if let decodedAdjustment = try container.decodeIfPresent(Double.self, forKey: .rhrAdjustment) {
            rhrAdjustment = decodedAdjustment
        } else if let decodedPenalty = try container.decodeIfPresent(Double.self, forKey: .rhrPenalty) {
            rhrAdjustment = -decodedPenalty
        } else {
            rhrAdjustment = 0
        }
        todayRHR = try container.decodeIfPresent(Double.self, forKey: .todayRHR)
        yesterdayRHR = try container.decodeIfPresent(Double.self, forKey: .yesterdayRHR)
        baselineRHR = try container.decodeIfPresent(Double.self, forKey: .baselineRHR)
        rhrDeltaFromBaseline = try container.decodeIfPresent(Double.self, forKey: .rhrDeltaFromBaseline)
        rhrBaselineDays = try container.decodeIfPresent(Int.self, forKey: .rhrBaselineDays) ?? 0
        displayRHR = try container.decodeIfPresent(Double.self, forKey: .displayRHR)
        displayRHRDate = try container.decodeIfPresent(Date.self, forKey: .displayRHRDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(todayHRV, forKey: .todayHRV)
        try container.encode(baselineHRV, forKey: .baselineHRV)
        try container.encode(zScore, forKey: .zScore)
        try container.encode(stdDev, forKey: .stdDev)
        try container.encode(effectiveStdDev, forKey: .effectiveStdDev)
        try container.encode(daysInBaseline, forKey: .daysInBaseline)
        try container.encode(todayDate, forKey: .todayDate)
        try container.encode(rawScore, forKey: .rawScore)
        try container.encode(rhrAdjustment, forKey: .rhrAdjustment)
        try container.encodeIfPresent(todayRHR, forKey: .todayRHR)
        try container.encodeIfPresent(yesterdayRHR, forKey: .yesterdayRHR)
        try container.encodeIfPresent(baselineRHR, forKey: .baselineRHR)
        try container.encodeIfPresent(rhrDeltaFromBaseline, forKey: .rhrDeltaFromBaseline)
        try container.encode(rhrBaselineDays, forKey: .rhrBaselineDays)
        try container.encodeIfPresent(displayRHR, forKey: .displayRHR)
        try container.encodeIfPresent(displayRHRDate, forKey: .displayRHRDate)
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
