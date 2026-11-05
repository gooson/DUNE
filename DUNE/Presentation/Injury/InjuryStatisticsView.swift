import SwiftUI
import Charts

/// Injury statistics and volume comparison view.
struct InjuryStatisticsView: View {
    let statistics: InjuryStatistics
    let volumeComparisons: [InjuryVolumeComparison]

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var axisEdgePadding: CGFloat = 8
    @ScaledMetric(relativeTo: .caption) private var frequencyRowHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .caption) private var frequencyAxisHeight: CGFloat = 40

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                Color.clear
                    .frame(height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("injury-statistics-screen")

                overviewSection
                frequencySection
                if !volumeComparisons.isEmpty {
                    volumeComparisonSection
                }
            }
            .padding()
        }
        .accessibilityIdentifier("injury-statistics-scroll")
        .background { DetailWaveBackground() }
        .environment(\.waveColor, DS.Color.caution)
        .englishNavigationTitle("Injury Statistics")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Overview

    private var overviewRowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.md))
    }

    private var activeForeground: Color {
        let color = statistics.activeCount > 0 ? DS.Color.caution : Color.green
        return colorScheme == .light ? color.mix(with: .black, by: 0.45) : color
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Label("Overview", systemImage: "chart.bar.xaxis")
                .font(DS.Typography.sectionTitle)
                .frame(maxWidth: .infinity, alignment: .leading)

            HeroCard(tintColor: DS.Color.caution) {
                overviewRowLayout {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Label("Total", systemImage: "bandage.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.Color.textSecondary)
                        Text(statistics.totalCount.formattedWithSeparator)
                            .accessibilityIdentifier("injury-statistics-overview-total-value")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
                            .foregroundStyle(.primary)
                        Text("injuries recorded")
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Label("Active", systemImage: "bandage.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.Color.textSecondary)
                        Text(statistics.activeCount.formattedWithSeparator)
                            .accessibilityIdentifier("injury-statistics-overview-active-value")
                            .font(.system(.title, design: .rounded, weight: .bold).monospacedDigit())
                            .foregroundStyle(activeForeground)
                        Text("current")
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            overviewRowLayout {
                StatCard(
                    title: "Avg Recovery",
                    icon: "clock.arrow.circlepath",
                    value: statistics.averageRecoveryDays.map { "\(Int($0.rounded()).formattedWithSeparator)d" } ?? "—",
                    subtitle: "per injury",
                    valueIdentifier: "injury-statistics-overview-average-value"
                )
                StatCard(
                    title: "Longest",
                    icon: "calendar",
                    value: statistics.longestRecoveryDays.map { "\($0.formattedWithSeparator)d" } ?? "—",
                    subtitle: "recovery",
                    valueIdentifier: "injury-statistics-overview-longest-value"
                )
            }
        }
    }

    // MARK: - Frequency

    private var frequencyTickStride: Double {
        let maximum = statistics.frequencyByBodyPart.map(\.count).max() ?? 1
        return max(1, ceil(Double(maximum) / 4))
    }

    @ViewBuilder
    private var frequencySection: some View {
        if !statistics.frequencyByBodyPart.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Label("Frequency by Body Part", systemImage: "chart.bar.fill")
                    .font(DS.Typography.sectionTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    ForEach(statistics.frequencyByBodyPart, id: \.bodyPart) { item in
                        Text(verbatim: "\(item.bodyPart.displayName): \(item.count.formattedWithSeparator)")
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Chart(statistics.frequencyByBodyPart, id: \.bodyPart) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Body Part", item.bodyPart.displayName)
                    )
                    .foregroundStyle(DS.Color.caution.gradient)
                    .cornerRadius(4)
                }
                .chartXScale(
                    domain: 0...max(1, statistics.frequencyByBodyPart.map(\.count).max() ?? 1),
                    range: .plotDimension(padding: axisEdgePadding)
                )
                .chartXAxis {
                    AxisMarks(values: .stride(by: frequencyTickStride)) { _ in
                        AxisValueLabel()
                            .foregroundStyle(DS.Color.textSecondary)
                        AxisGridLine()
                            .foregroundStyle(theme.accentColor.opacity(0.30))
                    }
                }
                .frame(height: max(120, CGFloat(statistics.frequencyByBodyPart.count) * frequencyRowHeight + frequencyAxisHeight))
                .accessibilityIdentifier("injury-statistics-frequency-chart")
                .padding(DS.Spacing.md)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
    }

    // MARK: - Volume Comparison

    @ViewBuilder
    private var volumeComparisonSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Label("Exercise Volume Impact", systemImage: "figure.strengthtraining.traditional")
                .font(DS.Typography.sectionTitle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Workout count before, during, and after injury (14-day windows)")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)

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
    let title: LocalizedStringKey
    let icon: String
    let value: String
    let subtitle: LocalizedStringKey
    let valueIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)
            Text(value)
                .accessibilityIdentifier(valueIdentifier)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}

private struct VolumeBar: View {
    let label: LocalizedStringKey
    let count: Int
    let maxCount: Int
    let color: Color
    var isNA: Bool = false

    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var axisEdgePadding: CGFloat = 8

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(isNA ? "—" : "\(count)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(!isNA ? AnyShapeStyle(theme.sandColor) : AnyShapeStyle(.tertiary))

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
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
