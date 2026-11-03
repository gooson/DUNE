import SwiftUI
import SwiftData

struct ConsistencyWeekdayHeader: Identifiable, Equatable, Sendable {
    let index: Int
    let label: String

    var id: Int { index }

    static let defaults: [ConsistencyWeekdayHeader] = ["S", "M", "T", "W", "T", "F", "S"].enumerated().map {
        ConsistencyWeekdayHeader(index: $0.offset, label: $0.element)
    }
}

/// Detail view for workout consistency: streak cards, monthly calendar, and history.
struct ConsistencyDetailView: View {
    @State private var viewModel = ConsistencyDetailViewModel()
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var exerciseRecords: [ExerciseRecord]
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var calendarColumnWidth: CGFloat = 24

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    private let weekdayHeaders = ConsistencyWeekdayHeader.defaults

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
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("activity-consistency-detail-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Consistency")
        .task(id: exerciseRecords.count) {
            await viewModel.loadData(from: exerciseRecords)
        }
    }

    // MARK: - Streak Summary Cards

    private func streakCards(_ streak: WorkoutStreak) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: DS.Spacing.md) {
                    statCard(title: "Current Streak", value: streak.currentStreak, icon: "flame.fill", id: "current")
                    statCard(title: "Best Streak", value: streak.bestStreak, icon: "star.fill", id: "best")
                }
            } else {
                HStack(spacing: DS.Spacing.md) {
                    statCard(title: "Current Streak", value: streak.currentStreak, icon: "flame.fill", id: "current")
                    statCard(title: "Best Streak", value: streak.bestStreak, icon: "star.fill", id: "best")
                }
            }
        }
    }

    private func statCard(title: LocalizedStringKey, value: Int, icon: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(palette.heroAccent)
                    .padding(DS.Spacing.sm)
                    .frame(minWidth: 36, minHeight: 36)
                    .background(palette.heroAccent.opacity(0.16), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text(value.formattedWithSeparator)
                    .font(.title.bold())
                    .monospacedDigit()
                    .foregroundStyle(palette.ink)
                    .accessibilityIdentifier("activity-consistency-\(id)-value")
                Text("days")
                    .font(.caption)
                    .foregroundStyle(palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay { RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(palette.border, lineWidth: 1) }
    }

    private func leadingTile(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DS.Color.activity)
            .padding(DS.Spacing.sm)
            .frame(minWidth: 36, minHeight: 36)
            .background(DS.Color.activity.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .accessibilityHidden(true)
    }

    // MARK: - Monthly Calendar (GitHub contribution style)

    private var monthlyCalendar: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("This Month")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.horizontal, showsIndicators: true) {
                    calendarGrid(columns: Array(repeating: GridItem(.fixed(calendarColumnWidth), spacing: 4), count: 7))
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("activity-consistency-calendar-horizontal")
            } else {
                calendarGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7))
            }

            // Monthly progress
            if let streak = viewModel.workoutStreak {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        leadingTile("calendar")
                        Text("Monthly Progress")
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(streak.monthlyCount)/\(streak.monthlyGoal)")
                            .accessibilityIdentifier("activity-consistency-month-progress")
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack {
                        leadingTile("calendar")
                        Text("Monthly Progress")
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                        Spacer()
                        Text("\(streak.monthlyCount)/\(streak.monthlyGoal)")
                            .accessibilityIdentifier("activity-consistency-month-progress")
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-consistency-calendar")
    }

    private func calendarGrid(columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(weekdayHeaders) { header in
                Text(header.label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }

            // Leading spacers for alignment
            ForEach(0..<viewModel.cachedFirstWeekdayOffset, id: \.self) { _ in
                Color.clear.frame(minHeight: 28)
            }

            // Day cells
            ForEach(viewModel.cachedCalendarDays, id: \.self) { date in
                let hasWorkout = viewModel.hasWorkout(on: date)
                let isToday = Calendar.current.isDateInToday(date)
                let isFuture = date > Calendar.current.startOfDay(for: Date())
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.caption2)
                    .monospacedDigit()
                    .accessibilityLabel(Text(date, style: .date))
                    .accessibilityValue(isFuture ? Text("") : (hasWorkout ? Text("Workout") : Text("No workout of 20 minutes or more")))
                    .accessibilityHint(isToday ? Text("Today") : Text(""))
                    .accessibilityIdentifier("activity-consistency-day-\(Calendar.current.component(.day, from: date))-\(hasWorkout ? "workout" : "nonqualifying")\(isToday ? "-today" : "")")
                    .foregroundStyle(hasWorkout ? .white : .secondary)
                    .padding(.vertical, DS.Spacing.xs)
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .background(
                        hasWorkout ? DS.Color.activity : DS.Color.activity.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 4)
                    )
                    .overlay {
                        if isToday {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(DS.Color.activity, lineWidth: 1.5)
                        }
                    }
            }
        }
    }

    // MARK: - Streak History

    private var streakHistoryList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Streak History")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

            if viewModel.streakHistory.isEmpty {
                Text("No streak history yet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DS.Spacing.md)
            } else {
                ForEach(viewModel.streakHistory) { period in
                    let historyID = period.id == viewModel.streakHistory.first?.id ? "0" : String(period.startDate.timeIntervalSince1970)
                    HStack(alignment: .center, spacing: DS.Spacing.md) {
                        leadingTile("flame.fill")
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(period.days == 1
                                 ? String(localized: "1 day")
                                 : String(localized: "\(period.days.formattedWithSeparator) days"))
                                .accessibilityIdentifier("activity-consistency-history-days-\(historyID)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.heroTextGradient)
                            Text("\(period.startDate, style: .date) — \(period.endDate, style: .date)")
                                .accessibilityIdentifier("activity-consistency-history-dates-\(historyID)")
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, DS.Spacing.xs)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-consistency-history")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "flame")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)
            Text("No workout data yet.")
                .font(.headline)
                .foregroundStyle(DS.Color.textSecondary)
            Text("Work out regularly to build and track your streaks.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
        .accessibilityIdentifier("activity-consistency-empty-state")
    }
}
