import SwiftUI
import Charts

/// Detail view for Exercise Mix with donut chart and full frequency list.
struct ExerciseMixDetailView: View {
    let summary: ExerciseMixSummary
    @State private var viewModel = ExerciseMixDetailViewModel()

    @Environment(\.appTheme) private var theme
    @State private var selectedAngle: Double?
    @State private var selectedExercise: String?

    // Correction #83: static color cache — palette derived from ActivityCategory.allCases (excludes multiSport).
    // NOTE: Chart access is index-based (cycling palette), not category-keyed.
    // Adding a new ActivityCategory case changes palette assignment — aesthetic only, not a correctness issue.
    private enum Cache {
        static let chartColors: [Color] = ActivityCategory.allCases
            .filter { $0 != .multiSport }
            .map(\.color)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if viewModel.exerciseFrequencies.isEmpty {
                    emptyState
                } else {
                    compositionCard
                    weeklyCard
                    muscleCard
                    cardioCard
                    donutChart
                    fullFrequencyList
                }
            }
            .padding()
        }
        .accessibilityIdentifier("activity-exercise-mix-detail-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Exercise Mix")
        .task(id: summary.end) {
            viewModel.load(summary: summary)
        }
    }

    private var compositionCard: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Last 4 weeks")
                    .font(.headline)
                (Text(summary.start, format: .dateTime.month(.abbreviated).day())
                 + Text(" – ")
                 + Text(summary.end, format: .dateTime.month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(summary.total.formattedWithSeparator)
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                    Text("Workout records")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
                stackedBar(strength: summary.strength, cardio: summary.cardio,
                           other: summary.other, total: summary.total, height: 14)
                Text("Share of all workout records")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
                compositionRow("Strength", count: summary.strength, color: strengthColor)
                compositionRow("Cardio", count: summary.cardio, color: cardioColor)
                if summary.other > 0 {
                    compositionRow("Other", count: summary.other, color: otherColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("activity-exercise-mix-composition")
    }

    private var strengthColor: Color { DS.Color.activityStrength }
    private var cardioColor: Color { DS.Color.activityCardio }
    private var otherColor: Color { DS.Color.activityOther }

    private func stackedBar(strength: Int, cardio: Int, other: Int, total: Int, height: CGFloat = 9) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                strengthColor.frame(width: geometry.size.width * CGFloat(strength) / CGFloat(max(total, 1)))
                cardioColor.frame(width: geometry.size.width * CGFloat(cardio) / CGFloat(max(total, 1)))
                otherColor.frame(width: geometry.size.width * CGFloat(other) / CGFloat(max(total, 1)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: height)
        .background(DS.Color.activity.opacity(0.12), in: Capsule())
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    private func compositionRow(_ title: LocalizedStringKey, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack(spacing: DS.Spacing.xs) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title)
            }
            HStack(spacing: DS.Spacing.xs) {
                Text(count.formattedWithSeparator)
                Text(Double(count) / Double(max(summary.total, 1)), format: .percent.precision(.fractionLength(0)))
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .monospacedDigit()
        }
        .font(.subheadline)
    }

    private var weeklyCard: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Weekly mix")
                    .font(.headline)
                Text("Each bar uses that week's workout records.")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                ForEach(summary.weeks) { week in
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(week.start, format: .dateTime.month(.abbreviated).day())
                            Spacer(minLength: DS.Spacing.xs)
                            Text(week.total.formattedWithSeparator)
                                .monospacedDigit()
                        }
                        .font(.caption.weight(.medium))
                        stackedBar(strength: week.strength, cardio: week.cardio,
                                   other: week.other, total: week.total)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: DS.Spacing.md) {
                                weekLegend("Strength", count: week.strength, color: strengthColor)
                                weekLegend("Cardio", count: week.cardio, color: cardioColor)
                                if week.other > 0 {
                                    weekLegend("Other", count: week.other, color: otherColor)
                                }
                            }
                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                weekLegend("Strength", count: week.strength, color: strengthColor)
                                weekLegend("Cardio", count: week.cardio, color: cardioColor)
                                if week.other > 0 {
                                    weekLegend("Other", count: week.other, color: otherColor)
                                }
                            }
                        }
                        .font(.caption2)
                    }
                    .padding(.vertical, DS.Spacing.xxs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("activity-exercise-mix-weekly-chart")
    }

    private func weekLegend(_ title: LocalizedStringKey, count: Int, color: Color) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title)
            Text(count.formattedWithSeparator)
                .monospacedDigit()
        }
    }

    private var muscleCard: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Primary muscles")
                    .font(.headline)
                Text("Completed sets are split evenly across primary muscles.")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                if summary.muscles.isEmpty {
                    Text("No attributed strength sets yet.")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                } else {
                    ForEach(summary.muscles) { share in
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(share.muscle.displayName)
                                .font(.caption.weight(.medium))
                            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                                Text(share.sets, format: .number.precision(.fractionLength(0...1)))
                                    .monospacedDigit()
                                Text(share.fraction, format: .percent.precision(.fractionLength(0)))
                                    .foregroundStyle(DS.Color.textSecondary)
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            GeometryReader { geometry in
                                Capsule()
                                    .fill(strengthColor)
                                    .frame(width: geometry.size.width * CGFloat(share.fraction))
                            }
                            .frame(height: 6)
                            .background(strengthColor.opacity(0.12), in: Capsule())
                            .accessibilityHidden(true)
                        }
                    }
                }
                if summary.unattributedSets > 0 {
                    Text("\(summary.unattributedSets) sets have no primary muscle data and are excluded from these percentages.")
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("activity-exercise-mix-muscle-shares")
    }

    private var cardioCard: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Cardio types")
                    .font(.headline)
                if summary.cardioTypes.isEmpty {
                    Text("No cardio records in this period.")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                } else {
                    Text("Share of cardio records")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                    ForEach(summary.cardioTypes) { kind in
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(localizedExerciseName(kind.name))
                                .font(.subheadline.weight(.medium))
                            HStack(spacing: DS.Spacing.xs) {
                                Text(kind.count.formattedWithSeparator)
                                Text(Double(kind.count) / Double(max(summary.cardio, 1)),
                                     format: .percent.precision(.fractionLength(0)))
                                Spacer(minLength: DS.Spacing.xs)
                            }
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            GeometryReader { geometry in
                                Capsule()
                                    .fill(cardioColor)
                                    .frame(width: geometry.size.width * CGFloat(kind.count) / CGFloat(max(summary.cardio, 1)))
                            }
                            .frame(height: 6)
                            .background(cardioColor.opacity(0.12), in: Capsule())
                            .accessibilityHidden(true)
                            if kind.durationMinutes != nil || kind.distanceKm != nil {
                                cardioMeasures(kind)
                                .font(.caption2)
                                .foregroundStyle(DS.Color.textSecondary)
                            }
                        }
                        .padding(.vertical, DS.Spacing.xxs)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("activity-exercise-mix-cardio-types")
    }

    private func cardioMeasures(_ kind: ExerciseMixSummary.CardioType) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DS.Spacing.sm) {
                if let minutes = kind.durationMinutes {
                    cardioDuration(minutes)
                }
                if let kilometers = kind.distanceKm {
                    cardioDistance(kilometers)
                }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                if let minutes = kind.durationMinutes {
                    cardioDuration(minutes)
                }
                if let kilometers = kind.distanceKm {
                    cardioDistance(kilometers)
                }
            }
        }
    }

    private func cardioDuration(_ minutes: Double) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Text(minutes, format: .number.precision(.fractionLength(0)))
            Text("min")
        }
    }

    private func cardioDistance(_ kilometers: Double) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Text(kilometers, format: .number.precision(.fractionLength(0...1)))
            Text("km")
        }
    }

    // MARK: - Donut Chart

    private var displayFrequencies: [ExerciseFrequency] {
        let all = viewModel.exerciseFrequencies
        guard all.count > 8 else { return all }
        return Array(all.prefix(8))
    }

    private func colorFor(index: Int) -> Color {
        Cache.chartColors[index % Cache.chartColors.count]
    }

    private var donutChart: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Distribution")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

            Chart(Array(displayFrequencies.enumerated()), id: \.element.id) { index, freq in
                SectorMark(
                    angle: .value("Count", freq.count),
                    innerRadius: .ratio(0.6),
                    angularInset: 1
                )
                .foregroundStyle(colorFor(index: index))
                .opacity(selectedExercise == nil || selectedExercise == freq.exerciseName ? 1 : 0.4)
            }
            .chartAngleSelection(value: $selectedAngle)
            .frame(height: 200)
            .clipped()
            .overlay {
                donutCenterLabel
            }
            .sensoryFeedback(.selection, trigger: selectedExercise)
            .onChange(of: selectedAngle) { _, _ in updateDonutSelection() }

            // Legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.xs) {
                ForEach(Array(displayFrequencies.enumerated()), id: \.element.id) { index, freq in
                    HStack(spacing: DS.Spacing.xs) {
                        Circle().fill(colorFor(index: index)).frame(width: 8, height: 8)
                        Text(localizedExerciseName(freq.exerciseName))
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("\(freq.count.formattedWithSeparator)x")
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private var donutCenterLabel: some View {
        VStack(spacing: DS.Spacing.xxs) {
            if let name = selectedExercise,
               let freq = viewModel.frequencyByName[name] {
                Text(localizedExerciseName(name))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(freq.count.formattedWithSeparator)x")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
            } else {
                let total = viewModel.exerciseFrequencies.reduce(0) { $0 + $1.count }
                Text(total.formattedWithSeparator)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text("total")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: selectedExercise)
    }

    private func updateDonutSelection() {
        guard let angle = selectedAngle else {
            selectedExercise = nil
            return
        }
        let total = Double(displayFrequencies.reduce(0) { $0 + $1.count })
        guard total > 0 else { return }
        var cumulative = 0.0
        for freq in displayFrequencies {
            cumulative += Double(freq.count) / total * 360
            if angle <= cumulative {
                selectedExercise = freq.exerciseName
                return
            }
        }
    }

    // MARK: - Full Frequency List

    private var fullFrequencyList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("All Exercises")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

            ForEach(viewModel.exerciseFrequencies) { freq in
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack {
                        Text(localizedExerciseName(freq.exerciseName))
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text("\(freq.count.formattedWithSeparator)x")
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .monospacedDigit()
                    }

                    GeometryReader { geo in
                        Capsule()
                            .fill(theme.accentColor.opacity(0.15))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(theme.accentColor)
                                    .frame(width: geo.size.width * CGFloat(freq.percentage))
                            }
                    }
                    .frame(height: 4)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)
            Text("No exercise data yet.")
                .font(.headline)
                .foregroundStyle(DS.Color.textSecondary)
            Text("Exercise distribution will appear after a few workouts.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }

    private func localizedExerciseName(_ name: String) -> String {
        WorkoutActivityType.localizedDisplayName(forStoredTitle: name) ?? name
    }
}
