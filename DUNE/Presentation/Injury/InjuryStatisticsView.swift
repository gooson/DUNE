import SwiftUI
import Charts

/// Injury statistics and volume comparison view.
struct InjuryStatisticsView: View {
    let statistics: InjuryStatistics
    let volumeComparisons: [InjuryVolumeComparison]

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                overviewSection
                frequencySection
                if !volumeComparisons.isEmpty {
                    volumeComparisonSection
                }
            }
            .padding()
        }
        .background { DetailWaveBackground() }
        .environment(\.waveColor, DS.Color.caution)
        .navigationTitle("Injury Statistics")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Overview")
                .font(DS.Typography.sectionTitle)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DS.Spacing.md) {
                StatCard(
                    title: "Total",
                    value: statistics.totalCount.formattedWithSeparator,
                    subtitle: "injuries recorded"
                )
                StatCard(
                    title: "Active",
                    value: statistics.activeCount.formattedWithSeparator,
                    subtitle: "current",
                    tintColor: statistics.activeCount > 0 ? DS.Color.caution : .green
                )
            }

            HStack(spacing: DS.Spacing.md) {
                StatCard(
                    title: "Avg Recovery",
                    value: statistics.averageRecoveryDays.map { "\(Int($0.rounded()).formattedWithSeparator)d" } ?? "—",
                    subtitle: "per injury"
                )
                StatCard(
                    title: "Longest",
                    value: statistics.longestRecoveryDays.map { "\($0.formattedWithSeparator)d" } ?? "—",
                    subtitle: "recovery"
                )
            }
        }
    }

    // MARK: - Frequency

    @ViewBuilder
    private var frequencySection: some View {
        if !statistics.frequencyByBodyPart.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Frequency by Body Part")
                    .font(DS.Typography.sectionTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Chart(statistics.frequencyByBodyPart, id: \.bodyPart) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Body Part", item.bodyPart.displayName)
                    )
                    .foregroundStyle(DS.Color.caution.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4))
                }
                .frame(height: CGFloat(statistics.frequencyByBodyPart.count) * 36)
                .clipped()
                .padding(DS.Spacing.md)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
    }

    // MARK: - Volume Comparison

    @ViewBuilder
    private var volumeComparisonSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Exercise Volume Impact")
                .font(DS.Typography.sectionTitle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Workout count before, during, and after injury (14-day windows)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(volumeComparisons) { comparison in
                volumeComparisonCard(comparison)
            }
        }
    }

    private func volumeComparisonCard(_ comparison: InjuryVolumeComparison) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: comparison.severity.iconName)
                    .foregroundStyle(comparison.severity.color)
                    .font(.caption)
                Text(comparison.bodyPart.displayName)
                    .font(.subheadline.weight(.medium))
            }

            HStack(spacing: DS.Spacing.md) {
                VolumeBar(
                    label: "Before",
                    count: comparison.preInjuryCount,
                    maxCount: maxVolumeCount(comparison),
                    color: .green
                )
                VolumeBar(
                    label: "During",
                    count: comparison.duringInjuryCount,
                    maxCount: maxVolumeCount(comparison),
                    color: DS.Color.caution
                )
                VolumeBar(
                    label: "After",
                    count: comparison.postInjuryCount ?? 0,
                    maxCount: maxVolumeCount(comparison),
                    color: comparison.postInjuryCount != nil ? .blue : .clear,
                    isNA: comparison.postInjuryCount == nil
                )
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private func maxVolumeCount(_ comparison: InjuryVolumeComparison) -> Int {
        Swift.max(
            comparison.preInjuryCount,
            comparison.duringInjuryCount,
            comparison.postInjuryCount ?? 0,
            1
        )
    }
}

// MARK: - Supporting Views

private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    var tintColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(tintColor)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}

private struct VolumeBar: View {
    let label: String
    let count: Int
    let maxCount: Int
    let color: Color
    var isNA: Bool = false

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(isNA ? "—" : "\(count)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(isNA ? .tertiary : .primary)

            GeometryReader { geo in
                let fraction = maxCount > 0 ? CGFloat(count) / CGFloat(maxCount) : 0
                RoundedRectangle(cornerRadius: 3)
                    .fill(isNA ? Color.clear : color.opacity(0.6))
                    .frame(height: geo.size.height * fraction)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 40)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
