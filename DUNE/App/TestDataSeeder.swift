import Foundation
import SwiftData

enum UITestSeedScenario: String {
    case empty = "empty"
    case defaultSeeded = "default-seeded"
    case activityExerciseSeeded = "activity-exercise-seeded"

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> UITestSeedScenario {
        guard let index = arguments.firstIndex(of: "--ui-scenario"),
              arguments.indices.contains(index + 1) else {
            return arguments.contains("--seed-mock") ? .defaultSeeded : .empty
        }
        return UITestSeedScenario(rawValue: arguments[index + 1])
            ?? (arguments.contains("--seed-mock") ? .defaultSeeded : .empty)
    }
}

#if DEBUG
/// Seeds mock SwiftData records for UI testing when launched with "--seed-mock".
enum TestDataSeeder {
    private static let forceCloudSyncConsentArgument = "--ui-force-cloud-sync-consent"
    static let activityExerciseMockWorkoutID = "ui-test-activity-workout-running"
    static let activityExerciseMissingWorkoutID = "ui-test-activity-workout-missing"
    static let activityExerciseCategoryID = "11111111-1111-4111-8111-111111111111"
    static let activityExerciseSingleTemplateID = "22222222-2222-4222-8222-222222222222"
    static let activityExerciseMultiTemplateID = "33333333-3333-4333-8333-333333333333"

    @MainActor
    static func seed(into context: ModelContext, scenario: UITestSeedScenario = .defaultSeeded) {
        resetUserDefaults()

        switch scenario {
        case .empty:
            return
        case .defaultSeeded:
            seedDefaultRecords(into: context)
        case .activityExerciseSeeded:
            seedDefaultRecords(into: context)
            seedActivityExerciseFixtures(into: context)
        }
    }

    static func resetUserDefaults(defaults: UserDefaults = .standard) {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.dailve"
        let keys = [
            "hasShownCloudSyncConsent",
            "isCloudSyncEnabled",
            "hasRequestedHealthKitAuthorization",
            "hasRequestedNotificationAuthorization",
            AppTheme.storageKey,
            "\(bundleID).notificationInbox.items",
            "\(bundleID).today.pinnedMetricCategories",
            "\(bundleID).whatsNew.lastOpenedBuild"
        ]

        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }

    static func shouldForceCloudSyncConsent(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(forceCloudSyncConsentArgument)
    }

    static func weatherSnapshot(for scenario: UITestSeedScenario) -> WeatherSnapshot? {
        switch scenario {
        case .empty:
            nil
        case .defaultSeeded, .activityExerciseSeeded:
            makeWeatherSnapshot()
        }
    }

    static func sharedHealthSnapshot(
        for scenario: UITestSeedScenario,
        fetchedAt: Date = Date()
    ) -> SharedHealthSnapshot? {
        switch scenario {
        case .empty:
            nil
        case .defaultSeeded, .activityExerciseSeeded:
            makeSharedHealthSnapshot(fetchedAt: fetchedAt)
        }
    }

    static func mockWorkoutSummary(
        for scenario: UITestSeedScenario,
        workoutID: String
    ) -> WorkoutSummary? {
        guard scenario == .activityExerciseSeeded,
              workoutID == activityExerciseMockWorkoutID else {
            return nil
        }

        let date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return WorkoutSummary(
            id: workoutID,
            type: "running",
            activityType: .running,
            duration: 35 * 60,
            calories: 420,
            distance: 6.2,
            date: date,
            isFromThisApp: false,
            heartRateAvg: 148,
            heartRateMax: 171,
            heartRateMin: 98,
            averagePace: 338,
            averageSpeed: 2.95,
            elevationAscended: 82,
            weatherTemperature: 18,
            weatherCondition: 1,
            weatherHumidity: 46,
            isIndoor: false,
            effortScore: 7.5,
            stepCount: 6_540,
            flightsClimbed: 9,
            milestoneDistance: .fiveK,
            isPersonalRecord: true,
            personalRecordTypes: [.fastestPace]
        )
    }

    static func mockRecentWorkouts(
        for scenario: UITestSeedScenario,
        referenceDate: Date
    ) -> [WorkoutSummary] {
        guard scenario == .activityExerciseSeeded else { return [] }

        let calendar = Calendar.current
        let referenceMorning = calendar.date(
            bySettingHour: 7,
            minute: 12,
            second: 0,
            of: referenceDate
        ) ?? referenceDate

        return [3, 8, 13, 20].compactMap { daysAgo in
            guard let workoutDate = calendar.date(byAdding: .day, value: -daysAgo, to: referenceMorning) else {
                return nil
            }

            return WorkoutSummary(
                id: "ui-test-recommendation-walking-\(daysAgo)",
                type: "Walking",
                activityType: .walking,
                duration: 4 * 60,
                calories: 34,
                distance: 320,
                date: workoutDate,
                isFromThisApp: false,
                heartRateAvg: 102,
                heartRateMax: 118,
                heartRateMin: 89,
                averagePace: 780,
                averageSpeed: 1.28,
                elevationAscended: nil,
                weatherTemperature: 17,
                weatherCondition: 1,
                weatherHumidity: 42,
                isIndoor: false,
                effortScore: 3.2,
                stepCount: 540,
                flightsClimbed: nil,
                milestoneDistance: nil,
                isPersonalRecord: false,
                personalRecordTypes: []
            )
        }
    }

    static func mockTemplateRecommendations(
        for scenario: UITestSeedScenario,
        referenceDate: Date
    ) -> [WorkoutTemplateRecommendation] {
        guard scenario == .activityExerciseSeeded else { return [] }

        let lastPerformedAt = Calendar.current.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate
        return [
            WorkoutTemplateRecommendation(
                id: "walking",
                title: "Morning Walking 4min",
                sequenceTypes: [.walking],
                sequenceLabels: ["Walking"],
                frequency: 4,
                averageDurationMinutes: 4,
                lastPerformedAt: lastPerformedAt,
                score: 1.4
            )
        ]
    }

    @MainActor
    private static func seedDefaultRecords(into context: ModelContext) {
        configureTodayDefaults()
        seedSharedHealthSnapshot(into: context)
        seedExerciseRecords(into: context)
        seedBodyCompositionRecords(into: context)
        seedInjuryRecords(into: context)
        seedHabitDefinitions(into: context)
        seedNotificationInbox(scenario: .defaultSeeded)
        try? context.save()
    }

    @MainActor
    private static func seedActivityExerciseFixtures(into context: ModelContext) {
        let category = UserCategory(
            name: "Codex Mobility",
            iconName: "figure.cooldown",
            colorHex: "34C759",
            defaultInputType: .durationIntensity,
            sortOrder: 0
        )
        category.id = UUID(uuidString: activityExerciseCategoryID) ?? category.id
        context.insert(category)

        let customExercise = CustomExercise(
            name: "Codex Cable Raise",
            category: .strength,
            inputType: .setsRepsWeight,
            primaryMuscles: [.shoulders],
            secondaryMuscles: [.triceps],
            equipment: .cable,
            metValue: 5.2,
            customCategoryName: category.name
        )
        context.insert(customExercise)

        let singleTemplate = WorkoutTemplate(
            name: "Codex Strength Starter",
            exerciseEntries: [
                TemplateEntry(
                    exerciseDefinitionID: "barbell-bench-press",
                    exerciseName: "Bench Press",
                    defaultSets: 2,
                    defaultReps: 8,
                    defaultWeightKg: 60,
                    restDuration: 45,
                    equipment: Equipment.barbell.rawValue,
                    inputTypeRaw: ExerciseInputType.setsRepsWeight.rawValue
                )
            ]
        )
        singleTemplate.id = UUID(uuidString: activityExerciseSingleTemplateID) ?? singleTemplate.id
        context.insert(singleTemplate)

        let multiTemplate = WorkoutTemplate(
            name: "Codex Circuit Builder",
            exerciseEntries: [
                TemplateEntry(
                    exerciseDefinitionID: "barbell-squat",
                    exerciseName: "Squat",
                    defaultSets: 2,
                    defaultReps: 6,
                    defaultWeightKg: 80,
                    restDuration: 60,
                    equipment: Equipment.barbell.rawValue,
                    inputTypeRaw: ExerciseInputType.setsRepsWeight.rawValue
                ),
                TemplateEntry(
                    exerciseDefinitionID: "barbell-bench-press",
                    exerciseName: "Bench Press",
                    defaultSets: 2,
                    defaultReps: 8,
                    defaultWeightKg: 60,
                    restDuration: 45,
                    equipment: Equipment.barbell.rawValue,
                    inputTypeRaw: ExerciseInputType.setsRepsWeight.rawValue
                )
            ]
        )
        multiTemplate.id = UUID(uuidString: activityExerciseMultiTemplateID) ?? multiTemplate.id
        context.insert(multiTemplate)

        seedNotificationInbox(scenario: .activityExerciseSeeded)
        try? context.save()
    }

    // MARK: - Exercise Records

    @MainActor
    private static func configureTodayDefaults() {
        TodayPinnedMetricsStore.shared.save([.hrv, .rhr])
    }

    @MainActor
    private static func seedSharedHealthSnapshot(into context: ModelContext) {
        guard let snapshot = sharedHealthSnapshot(for: .defaultSeeded, fetchedAt: Date()) else { return }
        let payload = HealthSnapshotMirrorMapper.makePayload(from: snapshot)
        guard let payloadJSON = try? HealthSnapshotMirrorMapper.encode(payload) else { return }

        context.insert(
            HealthSnapshotMirrorRecord(
                fetchedAt: snapshot.fetchedAt,
                syncedAt: snapshot.fetchedAt,
                sourceDevice: "UITest",
                payloadVersion: 1,
                payloadJSON: payloadJSON
            )
        )
    }

    private static func seedNotificationInbox(scenario: UITestSeedScenario) {
        let manager = NotificationInboxManager.shared
        manager.deleteAll()
        for insight in makeNotificationInsights(for: scenario) {
            _ = manager.recordSentInsight(insight)
        }
    }

    @MainActor
    private static func seedExerciseRecords(into context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let exercises: [(name: String, defID: String, type: String, muscles: [MuscleGroup])] = [
            ("Bench Press", "barbell-bench-press", "strength", [.chest, .triceps]),
            ("Squat", "barbell-squat", "strength", [.quadriceps, .glutes]),
            ("Deadlift", "conventional-deadlift", "strength", [.hamstrings, .back]),
        ]

        for (index, exercise) in exercises.enumerated() {
            let date = calendar.date(byAdding: .day, value: -index, to: today) ?? today
            let record = ExerciseRecord(
                date: date,
                exerciseType: exercise.type,
                duration: Double((30 + index * 10) * 60),
                calories: Double(200 + index * 50),
                exerciseDefinitionID: exercise.defID,
                primaryMuscles: exercise.muscles,
                equipment: .barbell
            )
            context.insert(record)

            var seededSets: [WorkoutSet] = []

            // Add workout sets after record is in context.
            // Set the inverse explicitly so SwiftData treats the record as set-backed
            // during the same seeded launch used by UI tests.
            for setNum in 1...3 {
                let set = WorkoutSet(
                    setNumber: setNum,
                    weight: Double(60 + index * 20),
                    reps: Swift.max(1, 10 - index),
                    isCompleted: true
                )
                set.exerciseRecord = record
                context.insert(set)
                seededSets.append(set)
            }

            record.sets = seededSets
        }
    }

    // MARK: - Body Composition

    @MainActor
    private static func seedBodyCompositionRecords(into context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for i in 0..<3 {
            let date = calendar.date(byAdding: .day, value: -i * 7, to: today) ?? today
            let record = BodyCompositionRecord(
                date: date,
                weight: 75.0 - Double(i) * 0.3,
                bodyFatPercentage: 18.0 + Double(i) * 0.2,
                muscleMass: 32.0 + Double(i) * 0.1
            )
            context.insert(record)
        }
    }

    // MARK: - Injury Records

    @MainActor
    private static func seedInjuryRecords(into context: ModelContext) {
        let record = InjuryRecord(
            bodyPart: .knee,
            bodySide: .left,
            severity: .minor,
            startDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            memo: "Mild pain during squats"
        )
        context.insert(record)
    }

    // MARK: - Habits

    @MainActor
    private static func seedHabitDefinitions(into context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let habits: [(name: String, icon: HabitIconCategory, type: HabitType, goal: Double, unit: String?)] = [
            ("Morning Stretch", .fitness, .check, 1.0, nil),
            ("Read", .study, .duration, 30.0, "min"),
            ("Water", .hydration, .count, 8.0, "glasses"),
        ]

        for (index, h) in habits.enumerated() {
            let definition = HabitDefinition(
                name: h.name,
                iconCategory: h.icon,
                habitType: h.type,
                goalValue: h.goal,
                goalUnit: h.unit,
                frequency: .daily,
                sortOrder: index
            )
            context.insert(definition)

            // Add a log for today for the first habit
            if index == 0 {
                let log = HabitLog(date: today, value: 1.0, completedAt: Date())
                context.insert(log)
                log.habitDefinition = definition
            }
        }
    }

    private static func makeNotificationInsights(
        for scenario: UITestSeedScenario,
        referenceDate: Date = Date()
    ) -> [HealthInsight] {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: referenceDate)
        var insights: [HealthInsight] = [
            HealthInsight(
                type: .sleepDebt,
                title: String(localized: "Sleep Debt Alert"),
                body: String(localized: "You slept 6 h 20 m last night. Prioritize recovery today."),
                severity: .attention,
                date: calendar.date(byAdding: .minute, value: -15, to: now) ?? now
            ),
            HealthInsight(
                type: .stepGoal,
                title: String(localized: "Step Goal Reached"),
                body: String(localized: "You reached 9,800 steps today. Great momentum."),
                severity: .celebration,
                date: calendar.date(byAdding: .minute, value: -45, to: now) ?? now
            )
        ]

        guard scenario == .activityExerciseSeeded else {
            return insights
        }

        insights.insert(
            HealthInsight(
                type: .workoutPR,
                title: String(localized: "Workout Detail Route"),
                body: String(localized: "Open the seeded running workout detail route."),
                severity: .celebration,
                date: calendar.date(byAdding: .minute, value: -5, to: now) ?? now,
                route: .workoutDetail(workoutID: activityExerciseMockWorkoutID)
            ),
            at: 0
        )
        insights.insert(
            HealthInsight(
                type: .workoutPR,
                title: String(localized: "Missing Workout Route"),
                body: String(localized: "Open the missing workout fallback screen."),
                severity: .attention,
                date: calendar.date(byAdding: .minute, value: -10, to: now) ?? now,
                route: .workoutDetail(workoutID: activityExerciseMissingWorkoutID)
            ),
            at: 1
        )
        return insights
    }

    private static func makeSharedHealthSnapshot(fetchedAt: Date) -> SharedHealthSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: fetchedAt)

        let hrvSamples: [HRVSample] = (0..<14).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return HRVSample(value: 66 - Double(offset), date: date)
        }

        let rhrCollection: [(date: Date, min: Double, max: Double, average: Double)] = (0..<14).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let average = 54 + Double(min(offset, 5))
            return (date: date, min: average - 1, max: average + 1, average: average)
        }

        let sleepDailyDurations: [SharedHealthSnapshot.SleepDailyDuration] = (0..<14).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return SharedHealthSnapshot.SleepDailyDuration(
                date: date,
                totalMinutes: 430 - Double(offset * 5),
                stageBreakdown: [
                    .deep: 92 - Double(min(offset, 4) * 3),
                    .rem: 108 - Double(min(offset, 4) * 2),
                    .core: 230 - Double(offset),
                    .awake: 18 + Double(min(offset, 4))
                ]
            )
        }

        let recentScores: [ConditionScore] = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return ConditionScore(score: max(55, 84 - offset * 3), date: date)
        }

        let todaySleepStages = makeSleepStages(
            day: today,
            deepMinutes: 92,
            remMinutes: 108,
            coreMinutes: 230,
            awakeMinutes: 18
        )
        let yesterdaySleepStages = makeSleepStages(
            day: calendar.date(byAdding: .day, value: -1, to: today) ?? today,
            deepMinutes: 88,
            remMinutes: 102,
            coreMinutes: 224,
            awakeMinutes: 16
        )

        return SharedHealthSnapshot(
            hrvSamples: hrvSamples,
            todayRHR: 54,
            yesterdayRHR: 56,
            latestRHR: nil,
            rhrCollection: rhrCollection,
            todaySleepStages: todaySleepStages,
            yesterdaySleepStages: yesterdaySleepStages,
            latestSleepStages: nil,
            sleepDailyDurations: sleepDailyDurations,
            conditionScore: ConditionScore(score: 84, date: today),
            baselineStatus: nil,
            recentConditionScores: recentScores,
            failedSources: [],
            fetchedAt: fetchedAt
        )
    }

    private static func makeSleepStages(
        day: Date,
        deepMinutes: Double,
        remMinutes: Double,
        coreMinutes: Double,
        awakeMinutes: Double
    ) -> [SleepStage] {
        let start = day.addingTimeInterval(60 * 60)
        var cursor = start
        var stages: [SleepStage] = []

        func appendStage(_ stage: SleepStage.Stage, minutes: Double) {
            guard minutes > 0 else { return }
            let duration = minutes * 60
            let end = cursor.addingTimeInterval(duration)
            stages.append(
                SleepStage(
                    stage: stage,
                    duration: duration,
                    startDate: cursor,
                    endDate: end
                )
            )
            cursor = end
        }

        appendStage(.deep, minutes: deepMinutes)
        appendStage(.rem, minutes: remMinutes)
        appendStage(.core, minutes: coreMinutes)
        appendStage(.awake, minutes: awakeMinutes)
        return stages
    }

    private static func makeWeatherSnapshot(referenceDate: Date = Date()) -> WeatherSnapshot {
        let calendar = Calendar.current
        let hourStart = calendar.dateInterval(of: .hour, for: referenceDate)?.start ?? referenceDate

        let hourlyForecast: [WeatherSnapshot.HourlyWeather] = (0..<6).compactMap { offset in
            guard let hour = calendar.date(byAdding: .hour, value: offset, to: hourStart) else { return nil }
            return WeatherSnapshot.HourlyWeather(
                hour: hour,
                temperature: 18 + Double(offset),
                condition: offset < 3 ? .clear : .partlyCloudy,
                feelsLike: 17 + Double(offset),
                humidity: 0.55,
                uvIndex: min(6, 2 + offset),
                windSpeed: 10 + Double(offset),
                precipitationProbability: offset == 4 ? 20 : 5
            )
        }

        let dailyForecast: [WeatherSnapshot.DailyForecast] = (0..<4).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: hourStart) else { return nil }
            return WeatherSnapshot.DailyForecast(
                date: date,
                temperatureMax: 23 + Double(offset),
                temperatureMin: 12 + Double(offset),
                condition: offset == 1 ? .partlyCloudy : .clear,
                precipitationProbabilityMax: offset == 2 ? 25 : 10,
                uvIndexMax: 6 + offset
            )
        }

        return WeatherSnapshot(
            temperature: 21,
            feelsLike: 22,
            condition: .clear,
            humidity: 0.56,
            uvIndex: 4,
            windSpeed: 12,
            isDaytime: true,
            fetchedAt: referenceDate,
            hourlyForecast: hourlyForecast,
            dailyForecast: dailyForecast,
            locationName: "Seoul",
            airQuality: nil
        )
    }
}
#endif
