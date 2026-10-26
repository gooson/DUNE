import SwiftUI

/// Compact root hero ring with a fixed 104pt outer diameter and a 97pt center path.
struct CompactConditionRing: View {
    let score: Int
    let ringColor: Color
    let highlightColor: Color
    let tipColor: Color
    let trackColor: Color
    let textColor: Color
    let accessibilityLabel: LocalizedStringKey
    var accessibilityIdentifier: String = "dashboard-hero-ring"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Double { Double(max(0, min(100, score))) / 100 }

    var body: some View {
        ZStack {
            Circle()
                .inset(by: 3.5)
                .stroke(trackColor.opacity(0.3), lineWidth: 7)

            if score >= 100 {
                Circle()
                    .inset(by: 3.5)
                    .stroke(ringGradient, lineWidth: 7)
                    .rotationEffect(.degrees(-90))
            } else if score > 0 {
                Circle()
                    .inset(by: 3.5)
                    .trim(from: 0, to: progress)
                    .stroke(ringGradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            Text(score.formatted())
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 104, height: 104)
        .shadow(color: highlightColor.opacity(reduceMotion ? 0 : 0.25), radius: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var ringGradient: AngularGradient {
        AngularGradient(
            colors: [ringColor.opacity(0.55), ringColor, highlightColor, tipColor],
            center: .center
        )
    }
}

#Preview("Condition 0") {
    CompactConditionRing(
        score: 0,
        ringColor: .orange,
        highlightColor: .yellow,
        tipColor: .green,
        trackColor: .brown,
        textColor: .white,
        accessibilityLabel: "Condition score \(0), \(ConditionScore.Status.warning.label)"
    )
    .padding()
    .background(.black)
}

#Preview("Condition 100") {
    CompactConditionRing(
        score: 100,
        ringColor: .orange,
        highlightColor: .yellow,
        tipColor: .green,
        trackColor: .brown,
        textColor: .white,
        accessibilityLabel: "Condition score \(100), \(ConditionScore.Status.excellent.label)"
    )
    .padding()
    .background(.black)
}
