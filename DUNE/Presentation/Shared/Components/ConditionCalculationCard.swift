import SwiftUI

/// Reusable card that shows the detailed breakdown of a Condition Score computation.
/// Used in both Dashboard (ConditionScoreDetailView) and Wellness (WellnessScoreDetailView).
struct ConditionCalculationCard: View {
    let detail: ConditionScoreDetail

    private let todayHRVText: String
    private let baselineHRVText: String
    private let zScoreText: String
    private let stdDevText: String
    private let stdDevSub: String
    private let zScoreSub: String
    private let rawScoreText: String
    private let dateText: String

    private let hasRHRSection: Bool
    private let hasRHRComparison: Bool
    private let rhrPrimaryLabel: String
    private let rhrPrimaryText: String
    private let rhrPrimarySub: String
    private let rhrBaselineText: String
    private let rhrBaselineSub: String
    private let rhrDeltaText: String
    private let rhrAdjustmentText: String

    init(detail: ConditionScoreDetail) {
        self.detail = detail
        todayHRVText = "\(detail.todayHRV.formattedWithSeparator(fractionDigits: 1)) ms"
        baselineHRVText = "\(detail.baselineHRV.formattedWithSeparator(fractionDigits: 1)) ms"
        zScoreText = detail.zScore.formattedWithSeparator(fractionDigits: 2, alwaysShowSign: true)
        zScoreSub = Self.zScoreLabel(detail.zScore)
        stdDevText = detail.stdDev.formattedWithSeparator(fractionDigits: 3)
        stdDevSub = detail.stdDev < detail.effectiveStdDev
            ? "floor \(detail.effectiveStdDev.formattedWithSeparator(fractionDigits: 2))"
            : String(localized: "natural")
        rawScoreText = detail.rawScore.formattedWithSeparator(fractionDigits: 1)
        dateText = Self.formatDate(detail.todayDate)

        let displayRHR = detail.todayRHR ?? detail.displayRHR
        hasRHRSection = displayRHR != nil || detail.baselineRHR != nil
        hasRHRComparison = detail.todayRHR != nil && detail.baselineRHR != nil && detail.rhrDeltaFromBaseline != nil

        if let todayRHR = detail.todayRHR {
            rhrPrimaryLabel = String(localized: "Today RHR")
            rhrPrimaryText = "\(todayRHR.formattedWithSeparator()) bpm"
            rhrPrimarySub = dateText
        } else if let displayRHR {
            rhrPrimaryLabel = String(localized: "Latest RHR")
            rhrPrimaryText = "\(displayRHR.formattedWithSeparator()) bpm"
            if let displayDate = detail.displayRHRDate {
                rhrPrimarySub = Self.formatDate(displayDate)
            } else {
                rhrPrimarySub = String(localized: "latest sample")
            }
        } else {
            rhrPrimaryLabel = String(localized: "RHR")
            rhrPrimaryText = "—"
            rhrPrimarySub = ""
        }

        if let baselineRHR = detail.baselineRHR {
            rhrBaselineText = "\(baselineRHR.formattedWithSeparator()) bpm"
            rhrBaselineSub = "\(detail.rhrBaselineDays.formattedWithSeparator) \(String(localized: "days"))"
        } else {
            rhrBaselineText = "—"
            rhrBaselineSub = String(localized: "building baseline")
        }

        if let delta = detail.rhrDeltaFromBaseline {
            rhrDeltaText = "\(delta.formattedWithSeparator(alwaysShowSign: true)) bpm"
        } else {
            rhrDeltaText = "—"
        }

        rhrAdjustmentText = detail.rhrAdjustment.formattedWithSeparator(
            fractionDigits: 1,
            alwaysShowSign: true
        )
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

                    CalculationRow(label: "Z-Score", value: zScoreText, sub: zScoreSub)
                    CalculationRow(label: "StdDev (ln)", value: stdDevText, sub: stdDevSub)

                    if hasRHRSection {
                        Divider()

                        CalculationRow(label: rhrPrimaryLabel, value: rhrPrimaryText, sub: rhrPrimarySub)
                        CalculationRow(label: "RHR Baseline", value: rhrBaselineText, sub: rhrBaselineSub)

                        if hasRHRComparison {
                            CalculationRow(
                                label: "RHR Delta",
                                value: rhrDeltaText,
                                sub: String(localized: "vs baseline")
                            )
                            CalculationRow(
                                label: "RHR Adjustment",
                                value: rhrAdjustmentText,
                                sub: String(localized: "baseline-relative")
                            )
                        }
                    }

                    Divider()

                    CalculationRow(label: "Raw Score", value: rawScoreText, sub: "clamped [0–100]")
                }
            }
        }
    }

    // MARK: - Private

    private static func zScoreLabel(_ z: Double) -> String {
        if z > 1.0 { return "well above" }
        if z > 0.5 { return "above avg" }
        if z > -0.5 { return "normal" }
        if z > -1.0 { return "slightly below" }
        if z > -2.0 { return "below avg" }
        return "well below"
    }

    private enum Cache {
        static let shortDate: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter
        }()
    }

    private static func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInYesterday(date) { return "yesterday" }
        return Cache.shortDate.string(from: date)
    }
}
