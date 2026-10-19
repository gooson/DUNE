import SwiftUI

/// The Today composition from the Desert Horizon direction: one dark surface
/// contains the score, its trend, the supporting signals, and the next action.
struct DesertHorizonConditionHeroView: View {
    let score: ConditionScore
    let trendBadges: [BaselineDetail]
    let hourlySparkline: HourlySparklineData?
    let adaptiveMessage: AdaptiveHeroMessage?
    let onPrimaryAction: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let surface = Color(red: 0.208, green: 0.180, blue: 0.161)
    private let gold = Color(red: 0.886, green: 0.718, blue: 0.380)
    private let paleGold = Color(red: 0.969, green: 0.843, blue: 0.471)
    private let muted = Color(red: 0.831, green: 0.784, blue: 0.722)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: score) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    Rectangle()
                        .fill(Color(red: 0.412, green: 0.341, blue: 0.278))
                        .frame(height: 1)
                    trend
                    evidence
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dashboard-hero-condition")

            Button(action: onPrimaryAction) {
                HStack {
                    Spacer()
                    if score.status == .tired || score.status == .warning {
                        Text("View Wellness")
                    } else {
                        Text("View Activity")
                    }
                    Image(systemName: "arrow.right")
                    Spacer()
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(surface)
                .frame(minHeight: 48)
                .background(gold, in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dashboard-primary-activity")
            .padding(.top, 16)
        }
        .padding(21)
        .background {
            RoundedRectangle(cornerRadius: 25)
                .fill(surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 25)
                        .strokeBorder(Color(red: 0.455, green: 0.365, blue: 0.263), lineWidth: 1)
                }
                .shadow(color: Color(red: 0.455, green: 0.357, blue: 0.196).opacity(0.16), radius: 16, y: 9)
        }
    }

    private var header: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 18) {
                    ring
                    statusText
                }
            } else {
                HStack(alignment: .center, spacing: 18) {
                    ring
                    statusText
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0.435, green: 0.353, blue: 0.227).opacity(0.7), lineWidth: 11)
            Circle()
                .trim(from: 0, to: CGFloat(score.score) / 100)
                .stroke(
                    AngularGradient(colors: [Color(red: 0.573, green: 0.467, blue: 0.263), gold, paleGold, Color(red: 0.596, green: 0.863, blue: 0.584)], center: .center),
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: paleGold.opacity(reduceMotion ? 0 : 0.4), radius: 5)
            VStack(spacing: 2) {
                Text(score.score.formatted())
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("CONDITION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(muted)
            }
            .foregroundStyle(Color(red: 1, green: 0.961, blue: 0.910))
        }
        .frame(width: 124, height: 124)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Condition score \(score.score), \(score.status.label)")
    }

    private var statusText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Condition")
                .font(.caption.weight(.bold))
                .foregroundStyle(gold)
            Text(score.status.guideMessage)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color(red: 1, green: 0.961, blue: 0.910))
                .fixedSize(horizontal: false, vertical: true)
            Text(adaptiveMessage?.message ?? score.narrativeMessage)
                .font(.subheadline)
                .foregroundStyle(muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var trend: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Condition Trend")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("24h")
                    .font(.caption)
                    .foregroundStyle(muted)
            }
            .foregroundStyle(Color(red: 0.933, green: 0.878, blue: 0.792))

            if let hourlySparkline, hourlySparkline.points.count >= 2 {
                HourlySparklineView(data: hourlySparkline, tintColor: paleGold, height: 72)
            } else {
                Text("Not enough data to show trend.")
                    .font(.subheadline)
                    .foregroundStyle(muted)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
            }
        }
    }

    private var evidence: some View {
        HStack(spacing: 8) {
            ForEach(Array(trendBadges.prefix(2).enumerated()), id: \.offset) { _, detail in
                HStack(spacing: 4) {
                    Text(detail.label)
                        .foregroundStyle(Color(red: 0.965, green: 0.929, blue: 0.882))
                    Text(detail.value.formattedWithSeparator(fractionDigits: detail.fractionDigits))
                        .foregroundStyle(Color(red: 0.710, green: 0.863, blue: 0.667))
                }
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color(red: 0.290, green: 0.251, blue: 0.208), in: RoundedRectangle(cornerRadius: 12))
            }
            Spacer(minLength: 0)
        }
    }
}
