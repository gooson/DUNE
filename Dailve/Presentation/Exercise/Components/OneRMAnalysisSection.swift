import SwiftUI

struct OneRMAnalysisSection: View {
    let analysis: OneRMAnalysis
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.kg.rawValue

    private var unit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .kg
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                Text("Estimated 1RM")
                    .font(.headline)
                Spacer()
            }

            if let best = analysis.currentBest {
                // Big number
                Text(formatWeight(best))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Color.activity)

                // Formula comparison
                if !analysis.formulaComparison.isEmpty {
                    formulaComparisonView
                }

                // Training zones
                if !analysis.trainingZones.isEmpty {
                    trainingZonesView
                }
            } else {
                Text("Complete a set with weight + reps to estimate your 1RM")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Formula Comparison

    private var formulaComparisonView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("By Formula")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(analysis.formulaComparison, id: \.formula) { estimate in
                HStack {
                    Text(estimate.formula.rawValue)
                        .font(.subheadline)
                    Spacer()
                    Text(formatWeight(estimate.estimatedMax))
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                }
            }

            if let first = analysis.formulaComparison.first {
                Text("Based on \(formatWeight(first.basedOnWeight)) × \(first.basedOnReps) reps")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Training Zones

    private var trainingZonesView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Training Zones")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, DS.Spacing.xs)

            ForEach(analysis.trainingZones, id: \.name) { zone in
                HStack {
                    Text(zone.name)
                        .font(.subheadline)
                        .frame(width: 90, alignment: .leading)

                    Text(zone.repsRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 50)

                    Spacer()

                    Text("\(formatWeight(zone.weight.lowerBound))–\(formatWeight(zone.weight.upperBound))")
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatWeight(_ kg: Double) -> String {
        let converted = unit.fromKg(kg)
        if converted >= 100 {
            return "\(Int(converted.rounded())) \(unit.displayName)"
        }
        return String(format: "%.1f \(unit.displayName)", converted)
    }
}
