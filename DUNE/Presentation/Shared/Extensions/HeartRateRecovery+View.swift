import SwiftUI

extension HeartRateRecovery.Rating {
    var color: Color {
        switch self {
        case .low: .red
        case .normal: .yellow
        case .good: .green
        }
    }
}

/// Shared recovery row displayed in workout detail views.
struct HeartRateRecoveryRow: View {
    let recovery: HeartRateRecovery

    var body: some View {
        if recovery.hrr1 > 0 {
            let ratingColor = recovery.rating.color
            HStack {
                Label("Recovery", systemImage: "arrow.down.heart.fill")
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)

                Spacer()

                HStack(spacing: DS.Spacing.xs) {
                    Text("\(Int(recovery.hrr1))")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    Text("bpm")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                    Text(recovery.rating.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ratingColor)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(
                            ratingColor.opacity(0.15),
                            in: Capsule()
                        )
                }
            }
            .padding(.top, DS.Spacing.xs)
        }
    }
}
