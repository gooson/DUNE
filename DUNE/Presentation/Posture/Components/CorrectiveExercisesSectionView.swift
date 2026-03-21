#if !os(visionOS)
import SwiftUI

/// Shared section displaying corrective exercise recommendations for posture issues.
struct CorrectiveExercisesSectionView: View {
    let recommendations: [CorrectiveRecommendation]

    var body: some View {
        if !recommendations.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Recommended Exercises")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                ForEach(recommendations) { rec in
                    let metricsDescription = rec.targetMetrics.map(\.displayName).joined(separator: ", ")
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: rec.exercise.equipment.iconName)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.exercise.localizedName)
                                .font(.subheadline.weight(.medium))

                            Text(metricsDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(rec.exercise.category.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(rec.exercise.localizedName), \(metricsDescription), \(rec.exercise.category.displayName)")
                }
            }
        }
    }
}
#endif
