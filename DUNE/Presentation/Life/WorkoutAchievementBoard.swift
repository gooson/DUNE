import SwiftUI

/// Display-only grouping and bounded visual progress for the weekly board.
struct WorkoutAchievementBoardModel {
    struct Group: Identifiable {
        let id: String
        let metrics: [LifeAutoAchievementProgress]

        var completedCount: Int { metrics.filter(\.isCompleted).count }
        var maxStreakWeeks: Int { metrics.map(\.streakWeeks).max() ?? 0 }
    }

    static let routineIDs = ["weeklyWorkout5", "weeklyWorkout7"]
    static let strengthIDs = ["weeklyStrength3", "weeklyChest3", "weeklyBack3", "weeklyLowerBody3", "weeklyShoulders3", "weeklyArms3"]
    static let runningIDs = ["weeklyRunning15km"]

    let customGoals: [HabitProgress]
    let groups: [Group]

    init(customGoals: [HabitProgress], metrics: [LifeAutoAchievementProgress]) {
        self.customGoals = customGoals
        let byID = Dictionary(metrics.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        groups = [
            Group(id: "routine", metrics: Self.routineIDs.compactMap { byID[$0] }),
            Group(id: "strength", metrics: Self.strengthIDs.compactMap { byID[$0] }),
            Group(id: "running", metrics: Self.runningIDs.compactMap { byID[$0] })
        ].filter { !$0.metrics.isEmpty }
    }

    var completedCount: Int { customGoals.filter(\.isCompleted).count + groups.reduce(0) { $0 + $1.completedCount } }
    var totalCount: Int { customGoals.count + groups.reduce(0) { $0 + $1.metrics.count } }
    var challengeCompletedCount: Int { groups.reduce(0) { $0 + $1.completedCount } }
    var challengeCount: Int { groups.reduce(0) { $0 + $1.metrics.count } }
    var maxStreakWeeks: Int { groups.map(\.maxStreakWeeks).max() ?? 0 }

    static func safeValue(_ value: Double) -> Double { value.isFinite ? max(0, value) : 0 }

    static func fraction(current: Double, target: Double) -> Double {
        guard current.isFinite, target.isFinite, target > 0 else { return 0 }
        return min(1, max(0, current / target))
    }

    static func display(_ value: Double) -> String {
        safeValue(value).formatted(.number.precision(.fractionLength(0...1)))
    }
}

struct WorkoutAchievementBoard: View {
    let customGoals: [HabitProgress]
    let metrics: [LifeAutoAchievementProgress]
    @Binding var isExpanded: Bool
    let actionButton: (HabitProgress) -> AnyView
    let contextMenu: (HabitProgress) -> AnyView

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var tileMinWidth: CGFloat = 86

    private var model: WorkoutAchievementBoardModel {
        WorkoutAchievementBoardModel(customGoals: customGoals, metrics: metrics)
    }
    private var gold: Color { theme == .desertWarm ? DS.Color.desertBronze : theme.accentColor }
    private var lightGold: Color { theme == .desertWarm ? DS.Color.warmGlow : theme.sandColor }
    private var weekDates: (Date, Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Calendar.current.timeZone
        calendar.locale = Calendar.current.locale
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        return (start, end)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 0) {
                if !customGoals.isEmpty {
                    ForEach(customGoals) { goal in
                        customGoalRow(goal)
                    }
                }
                challenges
                footer
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: DS.Radius.xxl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.xxl, style: .continuous)
                .strokeBorder(gold.opacity(DS.Opacity.cardBorder), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xxl, style: .continuous))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label("Weekly Workout Achievements", systemImage: "figure.run")
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(gold)
            Text(weekDates.0.formatted(.dateTime.month(.abbreviated).day()) + " – " + weekDates.1.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("life-workout-week-period")
            HStack(alignment: .center, spacing: DS.Spacing.lg) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    Text(model.completedCount.formatted())
                        .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 50 : 60, weight: .bold, design: .rounded))
                        .foregroundStyle(gold)
                    Text("/ \(model.totalCount)")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("Done")
                        .font(.caption)
                        .foregroundStyle(gold)
                }
                .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                if !dynamicTypeSize.isAccessibilitySize {
                    medal.accessibilityHidden(true)
                }
            }
            if !dynamicTypeSize.isAccessibilitySize && model.totalCount > 0 {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(0..<min(model.totalCount, 12), id: \.self) { index in
                        Circle()
                            .fill(index < model.completedCount ? gold : gold.opacity(0.16))
                            .frame(width: 13, height: 13)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Rectangle()
                .fill(LinearGradient(colors: [gold.opacity(colorScheme == .dark ? 0.22 : 0.14), lightGold.opacity(0.08), theme.cardBackground], startPoint: .topTrailing, endPoint: .bottomLeading))
                .overlay(alignment: .bottom) {
                    BoardTerrain()
                        .stroke(gold.opacity(0.22), lineWidth: 1)
                        .frame(height: 74)
                        .accessibilityHidden(true)
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(model.completedCount)/\(model.totalCount) done") + ", " + weekDates.0.formatted(.dateTime.month(.abbreviated).day()) + " – " + weekDates.1.formatted(.dateTime.month(.abbreviated).day()) + ", " + String(localized: "Workouts · Mon–Sun · DUNE + Apple Health"))
        .accessibilityIdentifier("life-workout-summary")
    }

    private var medal: some View {
        Image(systemName: "trophy")
            .font(.system(size: 29, weight: .light))
            .foregroundStyle(theme.bronzeColor)
            .frame(width: 66, height: 66)
            .background {
                Circle().fill(LinearGradient(colors: [lightGold, gold, theme.duskColor], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .padding(7)
            .background(Circle().strokeBorder(gold.opacity(0.8), lineWidth: 7))
            .opacity(model.completedCount == 0 ? 0.72 : 1)
    }

    private func customGoalRow(_ goal: HabitProgress) -> some View {
        ViewThatFits(in: .horizontal) {
            if !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: DS.Spacing.sm) {
                    goalIcon
                    goalName(goal)
                    Spacer(minLength: DS.Spacing.xs)
                    goalStatus(goal)
                    actionButton(goal)
                }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.sm) {
                    goalIcon
                    goalName(goal)
                    Spacer(minLength: 0)
                    actionButton(goal)
                }
                goalStatus(goal)
                    .padding(.leading, 40 + DS.Spacing.sm)
            }
        }
        .padding(.vertical, DS.Spacing.md)
        .overlay(alignment: .bottom) { Divider() }
        .contextMenu { contextMenu(goal) }
    }

    private var goalIcon: some View {
        Image(systemName: "star.fill")
            .foregroundStyle(gold)
            .frame(width: 40, height: 44)
            .background(gold.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .accessibilityHidden(true)
    }

    private func goalName(_ goal: HabitProgress) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text("My Goals · Today")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(goal.name)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("life-workout-goal-\(goal.name)")
        }
    }

    private func goalStatus(_ goal: HabitProgress) -> some View {
        Text(goal.isCompleted ? String(localized: "Completed") : "\(WorkoutAchievementBoardModel.display(goal.todayValue)) / \(WorkoutAchievementBoardModel.display(goal.goalValue))")
            .font(.caption)
            .foregroundStyle(goal.isCompleted ? DS.Color.positive : .secondary)
            .monospacedDigit()
    }

    private var challenges: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(DS.Animation.snappy) { isExpanded.toggle() }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Text("Workout Challenges")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    Text("\(model.challengeCompletedCount)/\(model.challengeCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .foregroundStyle(gold)
                .frame(maxWidth: .infinity, minHeight: 65)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("life-workout-challenges-toggle")
            .accessibilityValue(isExpanded ? String(localized: "Expanded") : String(localized: "Collapsed"))

            if isExpanded {
                if model.groups.isEmpty {
                    Text("No HealthKit-linked workouts yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(model.groups) { group in
                    groupView(group)
                }
            }
        }
    }

    @ViewBuilder
    private func groupView(_ group: WorkoutAchievementBoardModel.Group) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: groupIcon(group.id))
                    .foregroundStyle(gold)
                    .accessibilityHidden(true)
                Text(groupTitle(group.id))
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("life-workout-group-\(group.id)")
                Spacer()
                Text("\(group.completedCount)/\(group.metrics.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if group.id == "routine" { routine(group) }
            if group.id == "strength" { strength(group) }
            if group.id == "running" { running(group) }
            if group.maxStreakWeeks > 0 {
                Label(String(localized: "Best streak \(group.maxStreakWeeks)w"), systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(gold)
            }
        }
        .padding(.bottom, DS.Spacing.xl)
        .padding(.top, DS.Spacing.sm)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func routine(_ group: WorkoutAchievementBoardModel.Group) -> some View {
        let sessions = group.metrics.first { $0.id == "weeklyWorkout7" } ?? group.metrics[0]
        let count = WorkoutAchievementBoardModel.safeValue(sessions.currentValue)
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text(WorkoutAchievementBoardModel.display(count))
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                Text("workouts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: DS.Spacing.xs) {
                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Double(index) < count ? gold : gold.opacity(0.13))
                        .frame(maxWidth: .infinity)
                        .frame(height: 23)
                        .overlay {
                            if !dynamicTypeSize.isAccessibilitySize {
                                Text("\(index + 1)")
                                    .font(.caption2)
                                    .foregroundStyle(Double(index) < count ? theme.cardBackground : .secondary)
                            }
                        }
                }
            }
            .accessibilityHidden(true)
            ViewThatFits(in: .horizontal) {
                if !dynamicTypeSize.isAccessibilitySize {
                    HStack(spacing: DS.Spacing.lg) {
                        ForEach(group.metrics) { metric in routineMilestone(metric) }
                    }
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    ForEach(group.metrics) { metric in routineMilestone(metric) }
                }
            }
        }
    }

    private func routineMilestone(_ metric: LifeAutoAchievementProgress) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: metric.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(metric.isCompleted ? DS.Color.positive : gold)
            Text(metric.id == "weeklyWorkout5" ? String(localized: "Workout 5x") : String(localized: "Workout 7x"))
        }
        .font(.caption)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metric.title), \(WorkoutAchievementBoardModel.display(metric.currentValue)) / \(WorkoutAchievementBoardModel.display(metric.targetValue))")
        .accessibilityIdentifier("life-workout-metric-\(metric.id)")
    }

    private func strength(_ group: WorkoutAchievementBoardModel.Group) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: tileMinWidth), spacing: DS.Spacing.sm)], spacing: DS.Spacing.sm) {
            ForEach(group.metrics) { metric in
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(strengthTitle(metric.id))
                        .font(.caption)
                        .foregroundStyle(metric.isCompleted ? DS.Color.positive : .secondary)
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                        Text(WorkoutAchievementBoardModel.display(metric.currentValue))
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                        Text("/ " + WorkoutAchievementBoardModel.display(metric.targetValue) + " " + metric.unit)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .monospacedDigit()
                    HStack(spacing: 3) {
                        ForEach(0..<min(3, max(0, Int(metric.targetValue.isFinite ? min(metric.targetValue, 3) : 0))), id: \.self) { index in
                            Capsule().fill(Double(index) < WorkoutAchievementBoardModel.safeValue(metric.currentValue) ? gold : gold.opacity(0.15))
                                .frame(height: 5)
                        }
                    }
                    .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 83, alignment: .leading)
                .padding(DS.Spacing.sm)
                .background(gold.opacity(0.07), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("life-workout-metric-\(metric.id)")
            }
        }
    }

    private func running(_ group: WorkoutAchievementBoardModel.Group) -> some View {
        let metric = group.metrics[0]
        let current = WorkoutAchievementBoardModel.safeValue(metric.currentValue)
        let target = WorkoutAchievementBoardModel.safeValue(metric.targetValue)
        let remaining = max(0, target - current)
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ViewThatFits(in: .horizontal) {
                if !dynamicTypeSize.isAccessibilitySize {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        runningValue(current: current, target: target)
                        Spacer(minLength: 0)
                        runningRemaining(remaining: remaining, completed: metric.isCompleted)
                    }
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    runningValue(current: current, target: target)
                    runningRemaining(remaining: remaining, completed: metric.isCompleted)
                }
            }
            .monospacedDigit()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("life-workout-metric-\(metric.id)")
            ZStack {
                BoardTerrain().stroke(gold.opacity(0.18), lineWidth: 1)
                BoardRoad().stroke(gold.opacity(0.16), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                BoardRoad().trim(from: 0, to: WorkoutAchievementBoardModel.fraction(current: current, target: target))
                    .stroke(gold, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
            .frame(height: 67)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Running Distance"))
            .accessibilityIdentifier("life-workout-running-track")
            HStack {
                Text("0 km")
                Spacer()
                Text("\(WorkoutAchievementBoardModel.display(target)) km")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
    }

    private func runningValue(current: Double, target: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            Text(WorkoutAchievementBoardModel.display(current))
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
            Text("/ \(WorkoutAchievementBoardModel.display(target)) km")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func runningRemaining(remaining: Double, completed: Bool) -> some View {
        Text(completed ? String(localized: "Completed") : String(localized: "\(WorkoutAchievementBoardModel.display(remaining)) km remaining"))
            .font(.caption)
            .foregroundStyle(gold)
    }

    private var footer: some View {
        Text("Workouts · Mon–Sun · DUNE + Apple Health")
            .accessibilityIdentifier("life-workout-source")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.top, DS.Spacing.lg)
    }

    private func groupIcon(_ id: String) -> String {
        switch id {
        case "routine": "calendar.badge.clock"
        case "strength": "dumbbell.fill"
        default: "figure.run"
        }
    }

    private func groupTitle(_ id: String) -> String {
        switch id {
        case "routine": String(localized: "Routine Consistency")
        case "strength": String(localized: "Strength Split")
        default: String(localized: "Running Distance")
        }
    }

    private func strengthTitle(_ id: String) -> String {
        switch id {
        case "weeklyStrength3": String(localized: "Strength")
        case "weeklyChest3": String(localized: "Chest")
        case "weeklyBack3": String(localized: "Back")
        case "weeklyLowerBody3": String(localized: "Lower Body")
        case "weeklyShoulders3": String(localized: "Shoulders")
        default: String(localized: "Arms")
        }
    }
}

private struct BoardTerrain: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX - 10, y: rect.maxY * 0.8))
        path.addCurve(to: CGPoint(x: rect.maxX + 10, y: rect.maxY * 0.48), control1: CGPoint(x: rect.maxX * 0.33, y: rect.maxY * 0.2), control2: CGPoint(x: rect.maxX * 0.7, y: rect.maxY))
        return path
    }
}

private struct BoardRoad: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 3, y: rect.maxY * 0.8))
        path.addCurve(to: CGPoint(x: rect.maxX - 3, y: rect.maxY * 0.32), control1: CGPoint(x: rect.maxX * 0.38, y: rect.maxY * 0.95), control2: CGPoint(x: rect.maxX * 0.7, y: rect.maxY * 0.05))
        return path
    }
}

#Preview("Empty") {
    WorkoutAchievementBoard(customGoals: [], metrics: [], isExpanded: .constant(true), actionButton: { _ in AnyView(EmptyView()) }, contextMenu: { _ in AnyView(EmptyView()) })
        .padding()
}

#Preview("Progress") {
    WorkoutAchievementBoard(
        customGoals: [],
        metrics: [
            LifeAutoAchievementProgress(id: "weeklyWorkout5", title: "Workout 5x", currentValue: 4, targetValue: 5, unit: "workouts", isCompleted: false, streakWeeks: 0),
            LifeAutoAchievementProgress(id: "weeklyWorkout7", title: "Workout 7x", currentValue: 4, targetValue: 7, unit: "workouts", isCompleted: false, streakWeeks: 0),
            LifeAutoAchievementProgress(id: "weeklyStrength3", title: "Strength", currentValue: 2, targetValue: 3, unit: "workouts", isCompleted: false, streakWeeks: 0),
            LifeAutoAchievementProgress(id: "weeklyRunning15km", title: "Running", currentValue: 8.2, targetValue: 15, unit: "km", isCompleted: false, streakWeeks: 0)
        ],
        isExpanded: .constant(true),
        actionButton: { _ in AnyView(EmptyView()) },
        contextMenu: { _ in AnyView(EmptyView()) }
    )
    .padding()
}
