import SwiftUI

/// Compact badge showing auto-calculated workout intensity.
struct IntensityBadgeView: View {
    let intensity: WorkoutIntensityResult

    var body: some View {
        let levelColor = intensity.level.color
        let displayScore = intensity.rawScore.isFinite ? intensity.rawScore : 0

        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: intensity.level.iconName)
                .foregroundStyle(levelColor)
                .font(.body.weight(.semibold))

            VStack(alignment: .leading, spacing: 2) {
                Text(intensity.level.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(levelColor)

                Text("Intensity \u{00B7} \(Int(displayScore * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))

                    Capsule()
                        .fill(levelColor)
                        .frame(width: geo.size.width * displayScore)
                }
            }
            .frame(width: 60, height: 6)
        }
        .padding(DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(levelColor.opacity(DS.Opacity.border))
        }
    }
}
