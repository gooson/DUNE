import SwiftUI

/// Compact badge showing auto-calculated workout intensity.
struct IntensityBadgeView: View {
    let intensity: WorkoutIntensityResult

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: intensity.level.iconName)
                .foregroundStyle(intensity.level.color)
                .font(.body.weight(.semibold))

            VStack(alignment: .leading, spacing: 2) {
                Text(intensity.level.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(intensity.level.color)

                Text("Intensity \u{00B7} \(Int(intensity.rawScore * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Mini progress bar
            intensityBar
        }
        .padding(DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(intensity.level.color.opacity(DS.Opacity.border))
        }
    }

    private var intensityBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))

                Capsule()
                    .fill(intensity.level.color)
                    .frame(width: geo.size.width * intensity.rawScore)
            }
        }
        .frame(width: 60, height: 6)
    }
}
