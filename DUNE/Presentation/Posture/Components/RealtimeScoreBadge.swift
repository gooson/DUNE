import SwiftUI

/// Floating badge showing the realtime posture score with color feedback.
struct RealtimeScoreBadge: View {
    let score: Int
    let is3DActive: Bool

    var body: some View {
        let color = scoreColor
        HStack(spacing: 6) {
            Text("\(score)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: score)

            VStack(alignment: .leading, spacing: 1) {
                Text("SCORE")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                if is3DActive {
                    Text("3D")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.green.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var scoreColor: Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        return .red
    }
}
