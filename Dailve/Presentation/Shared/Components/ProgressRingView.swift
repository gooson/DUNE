import SwiftUI

struct ProgressRingView: View {
    let progress: Double // 0.0 ... 1.0
    let ringColor: Color
    var lineWidth: CGFloat = 14
    var size: CGFloat = 160

    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(ringColor.opacity(0.15), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            // Progress arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [ringColor.opacity(0.6), ringColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .onAppear {
            animatedProgress = 0
            if reduceMotion {
                animatedProgress = progress
            } else {
                withAnimation(DS.Animation.slow) {
                    animatedProgress = progress
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            if reduceMotion {
                animatedProgress = newValue
            } else {
                withAnimation(DS.Animation.emphasize) {
                    animatedProgress = newValue
                }
            }
        }
    }
}
