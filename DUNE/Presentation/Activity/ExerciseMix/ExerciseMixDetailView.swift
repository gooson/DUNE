import SwiftUI
import SwiftData
import Charts

/// Detail view for Exercise Mix with donut chart and full frequency list.
struct ExerciseMixDetailView: View {
    @State private var viewModel = ExerciseMixDetailViewModel()
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var exerciseRecords: [ExerciseRecord]

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
                    donutChart
                    fullFrequencyList
                }
            }
            .padding()
        }
        .background { DetailWaveBackground() }
        .navigationTitle("Exercise Mix")
        .task(id: exerciseRecords.count) {
            viewModel.loadData(from: exerciseRecords)
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
                .foregroundStyle(.secondary)

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
                        Text(freq.exerciseName)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("\(freq.count)x")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                Text(name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(freq.count)x")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                let total = viewModel.exerciseFrequencies.reduce(0) { $0 + $1.count }
                Text(total.formattedWithSeparator)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text("total")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)

            ForEach(viewModel.exerciseFrequencies) { freq in
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack {
                        Text(freq.exerciseName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text("\(freq.count)x")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    GeometryReader { geo in
                        Capsule()
                            .fill(DS.Color.warmGlow.opacity(0.15))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(DS.Color.warmGlow)
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
                .foregroundStyle(.secondary)
            Text("Exercise distribution will appear after a few workouts.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }
}
