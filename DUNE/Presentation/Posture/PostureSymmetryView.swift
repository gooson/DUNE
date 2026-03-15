import SwiftUI

/// Detailed left-right body symmetry comparison view.
struct PostureSymmetryView: View {
    let record: PostureAssessmentRecord
    @State private var viewModel = PostureSymmetryViewModel()

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
            .padding(.horizontal, DS.Spacing.lg)
        }
        .englishNavigationTitle("Symmetry Analysis")
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
                .foregroundStyle(DS.Color.body)

            Text("Left vs Right Comparison")
                .font(.headline)

            Text(record.date, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
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
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Metric title + status
            HStack {
                Image(systemName: detail.metric.iconName)
                    .foregroundStyle(detail.status.color)
                Text(detail.metric.displayName)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Label(detail.status.displayName, systemImage: detail.status.iconName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(detail.status.color)
            }

            // Left-right bar comparison
            HStack(spacing: DS.Spacing.md) {
                // Left side
                VStack(alignment: .trailing, spacing: 4) {
                    Text("L")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(formattedPostureMetricValue(detail.leftValue, unit: detail.unit))
                        .font(.callout.weight(.semibold).monospacedDigit())
                }
                .frame(width: 60, alignment: .trailing)

                // Visual bar
                symmetryBar(detail)

                // Right side
                VStack(alignment: .leading, spacing: 4) {
                    Text("R")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(formattedPostureMetricValue(detail.rightValue, unit: detail.unit))
                        .font(.callout.weight(.semibold).monospacedDigit())
                }
                .frame(width: 60, alignment: .leading)
            }

            // Difference summary
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: differenceIcon(detail))
                    .font(.caption)
                    .foregroundStyle(detail.status.color)

                Text(differenceSummary(detail))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
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
