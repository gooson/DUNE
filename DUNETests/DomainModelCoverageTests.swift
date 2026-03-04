import Foundation
import Testing
@testable import DUNE

@Suite("ActiveRecoverySuggestion")
struct ActiveRecoverySuggestionTests {
    @Test("Default suggestions include canonical IDs in fixed order")
    func defaultsCanonicalOrder() {
        let defaults = ActiveRecoverySuggestion.defaults
        #expect(defaults.map(\.id) == ["walking", "stretching", "yoga"])
    }

    @Test("Default suggestions include non-empty display metadata")
    func defaultsDisplayMetadata() {
        let defaults = ActiveRecoverySuggestion.defaults
        #expect(defaults.allSatisfy { !$0.title.isEmpty })
        #expect(defaults.allSatisfy { !$0.iconName.isEmpty })
        #expect(defaults.allSatisfy { !$0.duration.isEmpty })
    }
}

@Suite("InsightPriority")
struct InsightPriorityTests {
    @Test("Comparable ordering follows raw priority values")
    func comparableOrdering() {
        let values: [InsightPriority] = [.fallback, .critical, .medium, .celebration]
        #expect(values.sorted() == [.critical, .medium, .celebration, .fallback])
    }
}

@Suite("CoachingInsight")
struct CoachingInsightModelTests {
    @Test("Default actionHint is nil")
    func defaultActionHintNil() {
        let insight = CoachingInsight(
            id: "recovery-warning",
            priority: .critical,
            category: .recovery,
            title: "Recover",
            message: "Take it easy today",
            iconName: "heart.slash"
        )

        #expect(insight.actionHint == nil)
    }

    @Test("Hashable equality includes actionHint")
    func hashableIncludesActionHint() {
        let base = CoachingInsight(
            id: "start-workout",
            priority: .high,
            category: .training,
            title: "Start",
            message: "Begin a session",
            iconName: "figure.run"
        )
        let withHint = CoachingInsight(
            id: "start-workout",
            priority: .high,
            category: .training,
            title: "Start",
            message: "Begin a session",
            iconName: "figure.run",
            actionHint: "startWorkout"
        )

        #expect(base != withHint)
    }
}

@Suite("CompoundWorkoutConfig")
struct CompoundWorkoutConfigModelTests {
    private func makeExercise(id: String) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: "Exercise \(id)",
            localizedName: "Exercise \(id)",
            category: .strength,
            inputType: .setsRepsWeight,
            primaryMuscles: [.chest],
            secondaryMuscles: [.triceps],
            equipment: .barbell,
            metValue: 6.0
        )
    }

    @Test("isValid requires at least two exercises")
    func isValidRequiresTwoExercises() {
        let config = CompoundWorkoutConfig(
            exercises: [makeExercise(id: "one")],
            mode: .superset,
            totalRounds: 3,
            restBetweenExercises: 30
        )

        #expect(!config.isValid)
    }

    @Test("isValid requires totalRounds >= 1")
    func isValidRequiresPositiveRounds() {
        let config = CompoundWorkoutConfig(
            exercises: [makeExercise(id: "one"), makeExercise(id: "two")],
            mode: .circuit,
            totalRounds: 0,
            restBetweenExercises: 45
        )

        #expect(!config.isValid)
    }

    @Test("Equatable and Hashable use generated identity")
    func equatableUsesIdentity() {
        let exercises = [makeExercise(id: "one"), makeExercise(id: "two")]
        let first = CompoundWorkoutConfig(
            exercises: exercises,
            mode: .circuit,
            totalRounds: 4,
            restBetweenExercises: 40
        )
        let second = CompoundWorkoutConfig(
            exercises: exercises,
            mode: .circuit,
            totalRounds: 4,
            restBetweenExercises: 40
        )

        #expect(first != second)
        #expect(Set([first, second]).count == 2)
    }
}

@Suite("NotificationInboxItem")
struct NotificationInboxItemModelTests {
    @Test("workoutDetail route factory sets destination and workoutID")
    func routeFactory() {
        let route = NotificationRoute.workoutDetail(workoutID: "workout-123")
        #expect(route?.destination == .workoutDetail)
        #expect(route?.workoutID == "workout-123")
    }

    @Test("Codable round trip preserves all persisted fields")
    func codableRoundTrip() throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let openedAt = Date(timeIntervalSince1970: 1_700_000_120)
        let item = NotificationInboxItem(
            id: "item-1",
            insightType: .workoutPR,
            title: "New PR",
            body: "You set a new best",
            createdAt: createdAt,
            isRead: true,
            openedAt: openedAt,
            route: .workoutDetail(workoutID: "wk-1"),
            source: .localNotification
        )

        let encoded = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(NotificationInboxItem.self, from: encoded)
        #expect(decoded == item)
    }
}

@Suite("NotificationHubMetricResolver")
struct NotificationHubMetricResolverTests {
    @Test("Category mapping covers supported insight types")
    func categoryMapping() {
        #expect(NotificationHubMetricResolver.category(for: .hrvAnomaly) == .hrv)
        #expect(NotificationHubMetricResolver.category(for: .rhrAnomaly) == .rhr)
        #expect(NotificationHubMetricResolver.category(for: .sleepComplete) == .sleep)
        #expect(NotificationHubMetricResolver.category(for: .stepGoal) == .steps)
        #expect(NotificationHubMetricResolver.category(for: .weightUpdate) == .weight)
        #expect(NotificationHubMetricResolver.category(for: .bodyFatUpdate) == .bodyFat)
        #expect(NotificationHubMetricResolver.category(for: .bmiUpdate) == .bmi)
        #expect(NotificationHubMetricResolver.category(for: .workoutPR) == .exercise)
    }

    @Test("Metric parsing reads first numeric signal for HRV")
    func parseHRVValue() {
        let item = makeItem(
            insightType: .hrvAnomaly,
            body: "Today's HRV 37ms — 25% lower than usual"
        )

        let metric = NotificationHubMetricResolver.metric(for: item)

        #expect(metric?.category == .hrv)
        #expect(metric?.value == 37)
    }

    @Test("Metric parsing supports comma decimal for weight")
    func parseWeightDecimalComma() {
        let item = makeItem(
            insightType: .weightUpdate,
            body: "Weight: 70,5kg (+0,3)"
        )

        let metric = NotificationHubMetricResolver.metric(for: item)

        #expect(metric?.category == .weight)
        #expect(metric?.value == 70.5)
    }

    @Test("Sleep parsing supports Korean hour-minute format")
    func parseSleepKoreanHourMinute() {
        let item = makeItem(
            insightType: .sleepComplete,
            body: "지난밤: 7시간 20분 수면"
        )

        let metric = NotificationHubMetricResolver.metric(for: item)

        #expect(metric?.category == .sleep)
        #expect(metric?.value == 440)
    }

    @Test("Workout PR without route falls back to exercise metric with safe default value")
    func workoutPRFallbackMetric() {
        let item = makeItem(
            insightType: .workoutPR,
            body: "Running: New milestone"
        )

        let metric = NotificationHubMetricResolver.metric(for: item)

        #expect(metric?.category == .exercise)
        #expect(metric?.value == 0)
    }

    private func makeItem(insightType: HealthInsight.InsightType, body: String) -> NotificationInboxItem {
        NotificationInboxItem(
            id: UUID().uuidString,
            insightType: insightType,
            title: "Title",
            body: body,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            isRead: false,
            openedAt: nil,
            route: nil,
            source: .localNotification
        )
    }
}

@Suite("ScoreContribution")
struct ScoreContributionModelTests {
    @Test("id is derived from factor rawValue")
    func idDerivedFromFactor() {
        let hrv = ScoreContribution(factor: .hrv, impact: .positive, detail: "HRV up")
        let rhr = ScoreContribution(factor: .rhr, impact: .negative, detail: "RHR up")

        #expect(hrv.id == "hrv")
        #expect(rhr.id == "rhr")
    }

    @Test("Factor cases include HRV and RHR only")
    func factorCases() {
        #expect(Set(ScoreContribution.Factor.allCases) == Set([.hrv, .rhr]))
    }
}

@Suite("TrendAnalysis")
struct TrendAnalysisModelTests {
    @Test("Initializer defaults consecutiveDays and changePercent to zero")
    func initDefaults() {
        let analysis = TrendAnalysis(direction: .rising)
        #expect(analysis.consecutiveDays == 0)
        #expect(analysis.changePercent == 0)
    }

    @Test("insufficient constant uses insufficient direction with zero metrics")
    func insufficientConstant() {
        #expect(TrendAnalysis.insufficient.direction == .insufficient)
        #expect(TrendAnalysis.insufficient.consecutiveDays == 0)
        #expect(TrendAnalysis.insufficient.changePercent == 0)
    }
}

@Suite("BodyScoreDetail")
struct BodyScoreDetailModelTests {
    @Test("TrendLabel raw values remain stable")
    func trendLabelRawValues() {
        #expect(BodyScoreDetail.TrendLabel.stable.rawValue == "stable")
        #expect(BodyScoreDetail.TrendLabel.losing.rawValue == "losing")
        #expect(BodyScoreDetail.TrendLabel.gaining.rawValue == "gaining")
        #expect(BodyScoreDetail.TrendLabel.noData.rawValue == "no data")
    }

    @Test("Hashable equality tracks field changes")
    func hashableEquality() {
        let first = BodyScoreDetail(
            weightChange: -0.8,
            weightLabel: .losing,
            weightPoints: 12.5,
            baselinePoints: 50,
            finalScore: 63
        )
        let second = BodyScoreDetail(
            weightChange: -0.8,
            weightLabel: .losing,
            weightPoints: 12.5,
            baselinePoints: 50,
            finalScore: 63
        )
        let third = BodyScoreDetail(
            weightChange: 0.8,
            weightLabel: .gaining,
            weightPoints: -12.5,
            baselinePoints: 50,
            finalScore: 37
        )

        #expect(first == second)
        #expect(first != third)
    }
}

@Suite("StreakPeriod")
struct StreakPeriodModelTests {
    @Test("id matches startDate")
    func idMatchesStartDate() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_086_400)
        let period = StreakPeriod(id: start, startDate: start, endDate: end, days: 2)

        #expect(period.id == period.startDate)
    }
}

@Suite("WatchConnectivityModels Codable")
struct WatchConnectivityModelsTests {
    private func makeTemplateEntry() -> TemplateEntry {
        TemplateEntry(
            exerciseDefinitionID: "bench-press",
            exerciseName: "Bench Press",
            defaultSets: 4,
            defaultReps: 8,
            defaultWeightKg: 80,
            restDuration: 90,
            equipment: "barbell"
        )
    }

    @Test("WatchWorkoutState supports Codable round trip")
    func watchWorkoutStateRoundTrip() throws {
        let state = WatchWorkoutState(
            exerciseName: "Bench Press",
            exerciseID: "bench",
            currentSet: 2,
            totalSets: 4,
            targetWeight: 80,
            targetReps: 8,
            isActive: true
        )

        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(WatchWorkoutState.self, from: encoded)
        #expect(decoded.exerciseID == state.exerciseID)
        #expect(decoded.currentSet == state.currentSet)
        #expect(decoded.targetWeight == state.targetWeight)
        #expect(decoded.targetReps == state.targetReps)
        #expect(decoded.isActive == state.isActive)
    }

    @Test("WatchWorkoutUpdate supports Codable round trip with optional fields")
    func watchWorkoutUpdateRoundTrip() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_000_300)
        let update = WatchWorkoutUpdate(
            exerciseID: "squat",
            exerciseName: "Back Squat",
            completedSets: [
                WatchSetData(setNumber: 1, weight: 100, reps: 5, duration: 45, restDuration: 120, isCompleted: true)
            ],
            startTime: start,
            endTime: end,
            heartRateSamples: [
                WatchHeartRateSample(bpm: 145, timestamp: start.addingTimeInterval(30))
            ],
            rpe: 8
        )

        let encoded = try JSONEncoder().encode(update)
        let decoded = try JSONDecoder().decode(WatchWorkoutUpdate.self, from: encoded)
        #expect(decoded.exerciseID == update.exerciseID)
        #expect(decoded.completedSets.count == 1)
        #expect(decoded.completedSets[0].restDuration == 120)
        #expect(decoded.heartRateSamples.count == 1)
        #expect(decoded.rpe == 8)
    }

    @Test("WatchExerciseInfo preserves aliases and optional fields")
    func watchExerciseInfoRoundTrip() throws {
        let info = WatchExerciseInfo(
            id: "run",
            name: "Running",
            inputType: "durationDistance",
            defaultSets: 1,
            defaultReps: nil,
            defaultWeightKg: nil,
            equipment: nil,
            cardioSecondaryUnit: "pace",
            aliases: ["jogging", "run"]
        )

        let encoded = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(WatchExerciseInfo.self, from: encoded)
        #expect(decoded.aliases == ["jogging", "run"])
        #expect(decoded.cardioSecondaryUnit == "pace")
        #expect(decoded.defaultReps == nil)
        #expect(decoded.defaultWeightKg == nil)
    }

    @Test("WatchWorkoutTemplateInfo supports Codable round trip")
    func watchWorkoutTemplateInfoRoundTrip() throws {
        let template = WatchWorkoutTemplateInfo(
            id: UUID(),
            name: "Push Day",
            entries: [makeTemplateEntry()],
            updatedAt: Date(timeIntervalSince1970: 1_700_001_000)
        )

        let encoded = try JSONEncoder().encode(template)
        let decoded = try JSONDecoder().decode(WatchWorkoutTemplateInfo.self, from: encoded)
        #expect(decoded.id == template.id)
        #expect(decoded.name == "Push Day")
        #expect(decoded.entries.count == 1)
        #expect(decoded.entries[0].exerciseName == "Bench Press")
    }
}
