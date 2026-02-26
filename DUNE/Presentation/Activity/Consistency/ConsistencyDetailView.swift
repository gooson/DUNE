import SwiftUI
import SwiftData

/// Detail view for workout consistency: streak cards, monthly calendar, and history.
struct ConsistencyDetailView: View {
    @State private var viewModel = ConsistencyDetailViewModel()
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var exerciseRecords: [ExerciseRecord]

    private let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let streak = viewModel.workoutStreak {
                    streakCards(streak)
                    monthlyCalendar
                    streakHistoryList
                } else {
                    emptyState
                }
            }
            .padding()
        }
        .background { DetailWaveBackground() }
        .navigationTitle("Consistency")
        .task(id: exerciseRecords.count) {
            viewModel.loadData(from: exerciseRecords)
        }
    }

    // MARK: - Streak Summary Cards

    private func streakCards(_ streak: WorkoutStreak) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            statCard(title: "Current Streak", value: "\(streak.currentStreak)", unit: "days", icon: "flame.fill")
            statCard(title: "Best Streak", value: "\(streak.bestStreak)", unit: "days", icon: "star.fill")
        }
    }

    private func statCard(title: String, value: String, unit: String, icon: String) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(DS.Color.activity)

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                Text(value)
                    .font(.title.weight(.bold))
                    .monospacedDigit()
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Monthly Calendar (GitHub contribution style)

    private var monthlyCalendar: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("This Month")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            // Weekday headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }

                // Leading spacers for alignment
                ForEach(0..<viewModel.cachedFirstWeekdayOffset, id: \.self) { _ in
                    Color.clear.frame(height: 28)
                }

                // Day cells
                ForEach(viewModel.cachedCalendarDays, id: \.self) { date in
                    let hasWorkout = viewModel.hasWorkout(on: date)
                    let isToday = Calendar.current.isDateInToday(date)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hasWorkout ? DS.Color.activity : DS.Color.activity.opacity(0.08))
                        .frame(height: 28)
                        .overlay {
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(hasWorkout ? .white : .secondary)
                        }
                        .overlay {
                            if isToday {
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(DS.Color.activity, lineWidth: 1.5)
                            }
                        }
                }
            }

            // Monthly progress
            if let streak = viewModel.workoutStreak {
                HStack {
                    Text("Monthly Progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(streak.monthlyCount)/\(streak.monthlyGoal)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }

                GeometryReader { geo in
                    let fraction = CGFloat(streak.monthlyPercentage)
                    Capsule()
                        .fill(DS.Color.activity.opacity(0.15))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(DS.Color.activity)
                                .frame(width: geo.size.width * fraction)
                        }
                }
                .frame(height: 6)
                .clipShape(Capsule())
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Streak History

    private var streakHistoryList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Streak History")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if viewModel.streakHistory.isEmpty {
                Text("No streak history yet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DS.Spacing.md)
            } else {
                ForEach(viewModel.streakHistory) { period in
                    HStack {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text("\(period.days) days")
                                .font(.subheadline.weight(.semibold))
                            Text("\(period.startDate, style: .date) — \(period.endDate, style: .date)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(DS.Color.activity.opacity(0.6))
                    }
                    .padding(.vertical, DS.Spacing.xs)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "flame")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)
            Text("No workout data yet.")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Work out regularly to build and track your streaks.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }
}
