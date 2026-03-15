import SwiftUI

/// Vertical bar indicator showing camera distance status.
struct DistanceIndicatorView: View {
    let status: DistanceStatus

    private var indicatorPosition: CGFloat {
        switch status {
        case .tooFar: 0.15
        case .slightlyFar: 0.35
        case .optimal: 0.55
        case .tooClose: 0.85
        case .unknown: 0.5
        }
    }

    private var indicatorColor: Color {
        switch status {
        case .optimal: .green
        case .slightlyFar: .yellow
        case .tooFar, .tooClose: .red
        case .unknown: .gray
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(String(localized: "Near"))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Track
                    Capsule()
                        .fill(.white.opacity(0.15))

                    // Optimal zone highlight
                    Capsule()
                        .fill(.green.opacity(0.2))
                        .frame(height: geometry.size.height * 0.3)
                        .offset(y: -geometry.size.height * 0.2)

                    // Indicator dot
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 10, height: 10)
                        .shadow(color: indicatorColor.opacity(0.6), radius: 4)
                        .offset(y: -geometry.size.height * indicatorPosition + 5)
                        .animation(.easeInOut(duration: 0.3), value: status)
                }
            }
            .frame(width: 8)

            Text(String(localized: "Far"))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(width: 24, height: 120)
    }
}
