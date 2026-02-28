import SwiftUI

/// Reusable card that shows the detailed breakdown of a Condition Score computation.
/// Used in both Dashboard (ConditionScoreDetailView) and Wellness (WellnessScoreDetailView).
struct ConditionCalculationCard: View {
    let detail: ConditionScoreDetail

    // Pre-compute formatted strings to avoid allocation in body (Correction #80)
    private let todayHRVText: String
    private let baselineHRVText: String
    private let zScoreText: String
    private let stdDevText: String
    private let stdDevSub: String
    private let rhrPenaltyText: String
    private let rawScoreText: String
    private let dateText: String

    init(detail: ConditionScoreDetail) {
        self.detail = detail
        self.todayHRVText = String(format: "%.1f ms", detail.todayHRV)
        self.baselineHRVText = String(format: "%.1f ms", detail.baselineHRV)
        self.zScoreText = String(format: "%+.2f", detail.zScore)
        self.stdDevText = String(format: "%.3f", detail.stdDev)
        self.stdDevSub = detail.stdDev < detail.effectiveStdDev
            ? String(format: "→ floor %.2f", detail.effectiveStdDev)
            : "natural"
        self.rhrPenaltyText = String(format: "-%.1f", detail.rhrPenalty)
        self.rawScoreText = String(format: "%.1f", detail.rawScore)
        self.dateText = Self.formatDate(detail.todayDate)
    }

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "function")
                        .foregroundStyle(DS.Color.textSecondary)
                    Text("Condition Calculation")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                VStack(spacing: DS.Spacing.sm) {
                    CalculationRow(label: "Today HRV", value: todayHRVText, sub: dateText)
                    CalculationRow(label: "Baseline HRV", value: baselineHRVText, sub: "\(detail.daysInBaseline) days")

                    Divider()

                    CalculationRow(label: "Z-Score", value: zScoreText, sub: zScoreLabel(detail.zScore))
                    CalculationRow(label: "StdDev (ln)", value: stdDevText, sub: stdDevSub)

                    if detail.rhrPenalty > 0 {
                        CalculationRow(label: "RHR Penalty", value: rhrPenaltyText, sub: "")
                    }

                    Divider()

                    CalculationRow(label: "Raw Score", value: rawScoreText, sub: "clamped [0–100]")
                }
            }
        }
    }

    // MARK: - Private

    private func zScoreLabel(_ z: Double) -> String {
        if z > 1.0 { return "well above" }
        if z > 0.5 { return "above avg" }
        if z > -0.5 { return "normal" }
        if z > -1.0 { return "slightly below" }
        if z > -2.0 { return "below avg" }
        return "well below"
    }

    // Correction #80: DateFormatter cached as static let
    private enum Cache {
        static let shortDate: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "M/d"
            return f
        }()
    }

    private static func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInYesterday(date) { return "yesterday" }
        return Cache.shortDate.string(from: date)
    }
}
