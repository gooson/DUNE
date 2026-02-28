import SwiftUI
import Charts

/// Donut chart showing exercise type distribution by duration, calories, or sessions.
struct VolumeDonutChartView: View {
    let exerciseTypes: [ExerciseTypeVolume]
    @State private var selectedMetric: VolumeMetric = .duration
    @State private var selectedTypeKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("By Type")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(VolumeMetric.allCases, id: \.self) { metric in
                        Text(metric.displayName).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            if exerciseTypes.isEmpty {
                emptyState
            } else {
                chartContent
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartContent: some View {
        Chart(displayTypes, id: \.typeKey) { type in
            let value = metricValue(for: type)
            SectorMark(
                angle: .value("Value", value),
                innerRadius: .ratio(0.6),
                angularInset: 1
            )
            .foregroundStyle(type.color)
            .opacity(selectedTypeKey == nil || selectedTypeKey == type.typeKey ? 1 : 0.4)
        }
        .chartAngleSelection(value: $selectedAngle)
        .frame(height: 200)
        .clipped()
        .overlay {
            centerLabel
        }
        .sensoryFeedback(.selection, trigger: selectedTypeKey)
        .onChange(of: selectedAngle) { _, _ in updateSelection() }

        legendView
    }

    @State private var selectedAngle: Double?

    /// Maps selectedAngle to the corresponding type key.
    private func updateSelection() {
        guard let angle = selectedAngle else {
            selectedTypeKey = nil
            return
        }
        var cumulative = 0.0
        let total = displayTypes.reduce(0.0) { $0 + metricValue(for: $1) }
        guard total > 0 else { return }
        for type in displayTypes {
            let fraction = metricValue(for: type) / total
            cumulative += fraction * 360
            if angle <= cumulative {
                selectedTypeKey = type.typeKey
                return
            }
        }
    }

    private var centerLabel: some View {
        VStack(spacing: 2) {
            if let key = selectedTypeKey, let type = exerciseTypes.first(where: { $0.typeKey == key }) {
                Image(systemName: type.iconName)
                    .font(.title3)
                    .foregroundStyle(type.color)
                Text(type.displayName)
                    .font(.caption.weight(.semibold))
                Text(formattedMetricValue(for: type))
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
            } else {
                Text(totalLabel)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(selectedMetric.unitName)
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: selectedTypeKey)
    }

    private var legendView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.xs) {
            ForEach(displayTypes, id: \.typeKey) { type in
                HStack(spacing: DS.Spacing.xs) {
                    Circle().fill(type.color).frame(width: 8, height: 8)
                    Text(type.displayName)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(formattedMetricValue(for: type))
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Helpers

    /// Top 5 types + "Others" aggregate
    private var displayTypes: [ExerciseTypeVolume] {
        guard exerciseTypes.count > 5 else { return exerciseTypes }
        let top5 = Array(exerciseTypes.prefix(5))
        let rest = exerciseTypes.dropFirst(5)
        let otherDuration = rest.reduce(0.0) { $0 + $1.totalDuration }
        let otherCalories = rest.reduce(0.0) { $0 + $1.totalCalories }
        let otherSessions = rest.reduce(0) { $0 + $1.sessionCount }
        let other = ExerciseTypeVolume(
            typeKey: "other-combined",
            displayName: "Others",
            categoryRawValue: "other",
            equipmentRawValue: nil,
            totalDuration: otherDuration,
            totalCalories: otherCalories,
            sessionCount: otherSessions,
            totalDistance: nil,
            totalVolume: nil
        )
        return top5 + [other]
    }

    private func metricValue(for type: ExerciseTypeVolume) -> Double {
        switch selectedMetric {
        case .duration: type.totalDuration / 60.0
        case .calories: type.totalCalories
        case .sessions: Double(type.sessionCount)
        }
    }

    private func formattedMetricValue(for type: ExerciseTypeVolume) -> String {
        switch selectedMetric {
        case .duration:
            return type.totalDuration.formattedDuration()
        case .calories:
            return "\(type.totalCalories.formattedWithSeparator()) kcal"
        case .sessions:
            return type.sessionCount.formattedWithSeparator
        }
    }

    private var totalLabel: String {
        switch selectedMetric {
        case .duration:
            return exerciseTypes.reduce(0.0) { $0 + $1.totalDuration }.formattedDuration()
        case .calories:
            return exerciseTypes.reduce(0.0) { $0 + $1.totalCalories }.formattedWithSeparator()
        case .sessions:
            return exerciseTypes.reduce(0) { $0 + $1.sessionCount }.formattedWithSeparator
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "chart.pie.fill")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("No exercise data")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }
}

// MARK: - Volume Metric

enum VolumeMetric: String, CaseIterable {
    case duration, calories, sessions

    var displayName: String {
        switch self {
        case .duration: "Time"
        case .calories: "Cal"
        case .sessions: "Sessions"
        }
    }

    var unitName: String {
        switch self {
        case .duration: "min"
        case .calories: "kcal"
        case .sessions: "sessions"
        }
    }
}
