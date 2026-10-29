import SwiftUI

enum CardioAtlasFormatting {
    static func value(_ value: Double, kind: CardioJourneyProgress.Kind) -> String {
        switch kind {
        case .distanceMeters:
            (value / 1_000).formatted(.number.precision(.fractionLength(1))) + " km"
        case .durationSeconds:
            Duration.seconds(value).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
        }
    }

    static func journey(_ progress: CardioJourneyProgress) -> String {
        value(progress.total, kind: progress.kind) + " / " + value(progress.target, kind: progress.kind)
    }

    static func passport(count: Int) -> String {
        String(localized: "\(count) achievements")
    }

    static func achievement(_ kind: CardioAtlasAchievement.Kind, threshold: Double) -> String {
        switch kind {
        case .singleDistance: value(threshold, kind: .distanceMeters)
        case .singleDuration: value(threshold, kind: .durationSeconds)
        case .sessionCount: String(localized: "\(Int(threshold)) workouts")
        }
    }

    static func symbol(_ kind: CardioAtlasAchievement.Kind) -> String {
        switch kind {
        case .singleDistance: "point.topleft.down.to.point.bottomright.curvepath"
        case .singleDuration: "stopwatch"
        case .sessionCount: "medal"
        }
    }
}

struct CardioAtlasJourneyView: View {
    let progress: CardioAtlasProgress
    @Binding var distanceGoal: Double
    @Binding var durationGoal: Double
    let activityType: WorkoutActivityType
    @Environment(\.appTheme) private var theme

    private var journey: CardioJourneyProgress {
        progress.updatingJourneyGoal(distanceMeters: distanceGoal, durationSeconds: durationGoal).journey
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                Label(activityType.displayName, systemImage: activityType.iconName)
                    .font(.title2.weight(.semibold))
                Text(CardioAtlasFormatting.journey(journey))
                    .font(.largeTitle.weight(.bold).monospacedDigit())
                    .accessibilityIdentifier("cardio-journey-total")
                ProgressView(value: journey.fraction)
                    .tint(theme.accentColor)
                    .accessibilityLabel("Journey progress")
                Label {
                    Text(CardioAtlasFormatting.value(journey.currentContribution, kind: journey.kind))
                } icon: {
                    Image(systemName: "plus.circle")
                }
                .font(.title3)
                Text("Added by this workout")
                    .foregroundStyle(DS.Color.textSecondary)
                Group {
                    if journey.kind == .distanceMeters {
                        Picker("Journey goal", selection: $distanceGoal) {
                            ForEach([5_000.0, 10_000, 20_000, 50_000, 100_000], id: \.self) { goal in
                                Text(CardioAtlasFormatting.value(goal, kind: .distanceMeters)).tag(goal)
                            }
                        }
                    } else {
                        Picker("Journey goal", selection: $durationGoal) {
                            ForEach([1_800.0, 3_600, 10_800, 21_600, 36_000], id: \.self) { goal in
                                Text(CardioAtlasFormatting.value(goal, kind: .durationSeconds)).tag(goal)
                            }
                        }
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("cardio-journey-goal")
                Text("Progress from available history through this workout.")
                    .font(.footnote)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background { DetailWaveBackground() }
        .navigationTitle("Journey")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("cardio-atlas-journey-detail")
    }
}

struct CardioAtlasPassportView: View {
    let progress: CardioAtlasProgress
    let activityType: WorkoutActivityType
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                Label(activityType.displayName, systemImage: activityType.iconName)
                    .font(.title2.weight(.semibold))
                Text(CardioAtlasFormatting.passport(count: progress.achievements.count))
                    .font(.largeTitle.weight(.bold))
                Text("Achievements from available history")
                    .font(.footnote)
                    .foregroundStyle(DS.Color.textSecondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .top)], spacing: DS.Spacing.lg) {
                    ForEach(progress.achievements) { achievement in
                        VStack(spacing: DS.Spacing.sm) {
                            Image(systemName: CardioAtlasFormatting.symbol(achievement.kind))
                                .font(.largeTitle)
                                .foregroundStyle(theme.accentColor)
                            Text(CardioAtlasFormatting.achievement(achievement.kind, threshold: achievement.threshold))
                                .font(.headline)
                            Text(achievement.awardedAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                            if achievement.awardedSessionID == progress.earnedInCurrentSession.first(where: { $0.id == achievement.id })?.awardedSessionID {
                                Text("Earned in this workout")
                                    .font(.caption.weight(.medium))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DS.Spacing.lg)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
                        .accessibilityElement(children: .combine)
                    }
                }
                if !progress.nextAchievements.isEmpty {
                    Text("Next achievements").font(.title3.weight(.semibold))
                    ForEach(progress.nextAchievements) { next in
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Label(
                                CardioAtlasFormatting.achievement(next.kind, threshold: next.threshold),
                                systemImage: CardioAtlasFormatting.symbol(next.kind)
                            )
                            ProgressView(value: next.fraction).tint(theme.accentColor)
                        }
                    }
                }
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background { DetailWaveBackground() }
        .navigationTitle("Passport")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("cardio-atlas-passport-detail")
    }
}
