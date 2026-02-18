import SwiftUI

/// Apple Fitness-style activity ring showing progress toward a goal.
struct ActivityRingView: View {
    let progress: Double // 0.0 to 1.0+
    let ringColor: Color
    var lineWidth: CGFloat = 10
    var size: CGFloat = 60

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(ringColor.opacity(0.15), lineWidth: lineWidth)

            // Progress arc (capped at 1.0 for first layer)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    ringColor.gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Overflow arc for > 100%
            if progress > 1.0 {
                Circle()
                    .trim(from: 0, to: min(progress - 1.0, 1.0))
                    .stroke(
                        ringColor.opacity(0.6).gradient,
                        style: StrokeStyle(lineWidth: lineWidth * 0.7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: size, height: size)
        .animation(DS.Animation.standard, value: progress)
    }
}

/// Activity ring with centered label content.
struct LabeledActivityRingView<Label: View>: View {
    let progress: Double
    let ringColor: Color
    var lineWidth: CGFloat = 10
    var size: CGFloat = 120
    @ViewBuilder let label: () -> Label

    var body: some View {
        ZStack {
            ActivityRingView(
                progress: progress,
                ringColor: ringColor,
                lineWidth: lineWidth,
                size: size
            )
            label()
        }
    }
}

#Preview("50%") {
    ActivityRingView(progress: 0.5, ringColor: DS.Color.activity, size: 100)
}

#Preview("120%") {
    LabeledActivityRingView(progress: 1.2, ringColor: DS.Color.activity, size: 120) {
        VStack(spacing: 2) {
            Text("6")
                .font(.title2.bold())
            Text("/ 5일")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
