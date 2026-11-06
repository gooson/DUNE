import SwiftUI

/// Detailed left-right body symmetry comparison view.
struct PostureSymmetryView: View {
    let record: PostureAssessmentRecord
    @State private var viewModel = PostureSymmetryViewModel()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    private static let lightStatusColors: [PostureStatus: Color] = [
        .normal: .green.mix(with: .black, by: 0.55),
        .caution: .yellow.mix(with: .black, by: 0.55),
        .warning: .red.mix(with: .black, by: 0.55),
        .unmeasurable: .gray.mix(with: .black, by: 0.55)
    ]

    private func statusColor(_ status: PostureStatus) -> Color {
        colorScheme == .light ? Self.lightStatusColors[status, default: status.color] : status.color
    }


    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                if viewModel.hasData {
                    headerSection
                    symmetryCards
                } else {
                    noDataView
                }
            }
            .frame(maxWidth: 680)
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .englishNavigationTitle("Symmetry Analysis")
        .accessibilityIdentifier("posture-symmetry-screen")
        .navigationBarTitleDisplayMode(.inline)
        .background { DetailWaveBackground() }
        .environment(\.waveColor, DS.Color.body)
        .task { viewModel.loadSymmetry(from: record) }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.title)
                .foregroundStyle(palette.heroAccent)

            Text("Left vs Right Comparison")
                .font(.headline)
                .foregroundStyle(palette.ink)

            Text(record.date, style: .date)
                .font(.caption)
                .foregroundStyle(palette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.xl)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .strokeBorder(palette.border, lineWidth: 1)
        }
    }

    // MARK: - Symmetry Cards

    private var symmetryCards: some View {
        VStack(spacing: DS.Spacing.md) {
            ForEach(viewModel.symmetryDetails) { detail in
                symmetryCard(detail)
            }
        }
    }

    private func symmetryCard(_ detail: SymmetryDetail) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Metric title + status
                let titleLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
                    : AnyLayout(HStackLayout())
                titleLayout {
                    HStack {
                        Image(systemName: detail.metric.iconName)
                            .foregroundStyle(statusColor(detail.status))
                        Text(detail.metric.displayName)
                            .font(.subheadline.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                    Label(detail.status.displayName, systemImage: detail.status.iconName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusColor(detail.status))
                }

                // Left-right bar comparison
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: DS.Spacing.sm) {
                        HStack(spacing: DS.Spacing.xs) {
                            sideLabel("L", metric: detail.metric, side: "left")
                            metricValue(detail.leftValue, detail: detail, side: "left")
                            Spacer(minLength: 0)
                        }

                        symmetryBar(detail)

                        HStack(spacing: DS.Spacing.xs) {
                            Spacer(minLength: 0)
                            sideLabel("R", metric: detail.metric, side: "right")
                            metricValue(detail.rightValue, detail: detail, side: "right")
                        }
                    }
                } else {
                    HStack(spacing: DS.Spacing.md) {
                        VStack(alignment: .trailing, spacing: 4) {
                            sideLabel("L", metric: detail.metric, side: "left")
                            metricValue(detail.leftValue, detail: detail, side: "left")
                        }
                        .frame(width: 60, alignment: .trailing)

                        symmetryBar(detail)

                        VStack(alignment: .leading, spacing: 4) {
                            sideLabel("R", metric: detail.metric, side: "right")
                            metricValue(detail.rightValue, detail: detail, side: "right")
                        }
                        .frame(width: 60, alignment: .leading)
                    }
                }

                // Difference summary
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: differenceIcon(detail))
                        .font(.caption)
                        .foregroundStyle(statusColor(detail.status))

                    Text(differenceSummary(detail))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func sideLabel(_ label: LocalizedStringKey, metric: PostureMetricType, side: String) -> some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("posture-symmetry-side-\(metric.rawValue)-\(side)")
    }

    private func metricValue(_ value: Double, detail: SymmetryDetail, side: String) -> some View {
        Text(formattedPostureMetricValue(value, unit: detail.unit))
            .font(.callout.weight(.semibold).monospacedDigit())
            .fixedSize(horizontal: dynamicTypeSize.isAccessibilitySize, vertical: false)
            .accessibilityIdentifier("posture-symmetry-value-\(detail.metric.rawValue)-\(side)")
    }

    // MARK: - Symmetry Bar

    private func symmetryBar(_ detail: SymmetryDetail) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let maxVal = max(abs(detail.leftValue), abs(detail.rightValue))
            let leftRatio = maxVal > 0 ? CGFloat(abs(detail.leftValue)) / CGFloat(maxVal) : 0.5
            let rightRatio = maxVal > 0 ? CGFloat(abs(detail.rightValue)) / CGFloat(maxVal) : 0.5

            HStack(spacing: 2) {
                // Left bar (grows from right to left)
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 3)
                        .fill(detail.higherSide == .left ? detail.status.color : DS.Color.body.opacity(0.4))
                        .frame(width: max(4, width / 2 * leftRatio))
                }
                .frame(width: width / 2 - 1)

                // Center divider
                Rectangle()
                    .fill(.tertiary)
                    .frame(width: 2)

                // Right bar (grows from left to right)
                HStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(detail.higherSide == .right ? detail.status.color : DS.Color.body.opacity(0.4))
                        .frame(width: max(4, width / 2 * rightRatio))
                    Spacer()
                }
                .frame(width: width / 2 - 1)
            }
        }
        .frame(height: 24)
    }

    // MARK: - No Data

    private var noDataView: some View {
        ContentUnavailableView {
            Label(
                String(localized: "No Symmetry Data"),
                systemImage: "arrow.left.arrow.right"
            )
        } description: {
            Text("Front-view capture is required for left-right comparison.")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.xxxl)
    }

    // MARK: - Helpers

    private func differenceIcon(_ detail: SymmetryDetail) -> String {
        if detail.higherSide == .both { return "equal.circle" }
        return detail.higherSide == .left ? "arrow.left" : "arrow.right"
    }

    private func differenceSummary(_ detail: SymmetryDetail) -> String {
        let absDiff = abs(detail.difference)
        let formatted = formattedPostureMetricValue(absDiff, unit: detail.unit)

        if detail.higherSide == .both {
            return String(localized: "Balanced")
        }

        let side = detail.higherSide == .left
            ? String(localized: "Left")
            : String(localized: "Right")

        return String(localized: "\(side) higher by \(formatted)")
    }
}
