import Foundation

protocol WellnessScoreCalculating: Sendable {
    func execute(input: CalculateWellnessScoreUseCase.Input) -> WellnessScore?
}

struct CalculateWellnessScoreUseCase: WellnessScoreCalculating, Sendable {
    // Weight allocation (must sum to 1.0)
    private let sleepWeight = 0.40
    private let conditionWeight = 0.35
    private let bodyWeight = 0.25

    struct Input: Sendable {
        let sleepScore: Int?
        let conditionScore: Int?
        let bodyTrend: BodyTrend?
    }

    /// Body composition trend over the last 7 days.
    struct BodyTrend: Sendable {
        let weightChange: Double?   // kg change (negative = loss)

        /// Convert body trend into a 0-100 score.
        var score: Int { detail.finalScore }

        /// Detailed breakdown of the body score calculation.
        var detail: BodyScoreDetail {
            let baseline = 50.0
            var weightPts = 0.0
            var label: BodyScoreDetail.TrendLabel = .noData

            // Weight stability/loss is generally positive for fitness users
            // Correction #4: isFinite guard on math inputs
            if let wc = weightChange, wc.isFinite {
                let absChange = abs(wc)
                if absChange < 0.5 {
                    weightPts = 25 // stable weight
                    label = .stable
                } else if wc < 0 {
                    weightPts = 15 // losing weight (generally positive)
                    label = .losing
                } else {
                    weightPts = -min(15, absChange * 5) // gaining weight
                    label = .gaining
                }
            }

            let raw = baseline + weightPts
            let clamped = Int(max(0, min(100, raw)).rounded())

            return BodyScoreDetail(
                weightChange: weightChange,
                weightLabel: label,
                weightPoints: weightPts,
                baselinePoints: baseline,
                finalScore: clamped
            )
        }
    }

    func execute(input: Input) -> WellnessScore? {
        // Count available components
        let hasSleep = input.sleepScore != nil
        let hasCondition = input.conditionScore != nil
        let hasBody = input.bodyTrend != nil

        let componentCount = [hasSleep, hasCondition, hasBody].filter(\.self).count

        // Need at least 1 component to produce a score
        guard componentCount >= 1 else { return nil }

        let bodyScoreValue = input.bodyTrend?.score

        // Calculate weighted score, redistributing missing weights proportionally
        var totalWeight = 0.0
        var weightedSum = 0.0

        if let sleep = input.sleepScore {
            totalWeight += sleepWeight
            weightedSum += Double(sleep) * sleepWeight
        }
        if let condition = input.conditionScore {
            totalWeight += conditionWeight
            weightedSum += Double(condition) * conditionWeight
        }
        if let body = bodyScoreValue {
            totalWeight += bodyWeight
            weightedSum += Double(body) * bodyWeight
        }

        guard totalWeight > 0 else { return nil }

        let rawScore = weightedSum / totalWeight
        guard !rawScore.isNaN, !rawScore.isInfinite else { return nil }

        return WellnessScore(
            score: Int(rawScore.rounded()),
            sleepScore: input.sleepScore,
            conditionScore: input.conditionScore,
            bodyScore: bodyScoreValue
        )
    }
}
