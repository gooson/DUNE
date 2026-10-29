import Foundation
import SwiftData
#if DEBUG
import UIKit
#endif

enum UITestSeedScenario: String {
    case empty = "empty"
    case defaultSeeded = "default-seeded"
    case activityExerciseSeeded = "activity-exercise-seeded"
    case notificationRoutingSeeded = "notification-routing-seeded"
    case fatigueRegression = "fatigue-regression"

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
        if ProcessInfo.processInfo.arguments.contains("--ui-design-map-one-set") {
            WorkoutSettingsStore.shared.setCount = 1
        }
        configureSimulatorAdvancedMockData(for: scenario)

        switch scenario {
        case .empty:
            return
        case .defaultSeeded, .notificationRoutingSeeded:
            seedDefaultRecords(into: context, scenario: scenario)
        case .activityExerciseSeeded:
            seedDefaultRecords(into: context)
            seedActivityExerciseFixtures(into: context)
            if ProcessInfo.processInfo.arguments.contains("--ui-cardio-atlas-fixture") {
                seedCardioAtlasFixtures(into: context)
            }
        case .fatigueRegression:
            seedFatigueRegression(into: context)
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
            SimulatorAdvancedMockDataModeStore.storageKey,
            SimulatorAdvancedMockDataModeStore.referenceDateStorageKey,
            "\(bundleID).notificationInbox.items",
            "\(bundleID).workoutRewards.state",
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

    static func configureSimulatorAdvancedMockData(
        for scenario: UITestSeedScenario,
        defaults: UserDefaults = .standard,
        referenceDate: Date = Date()
    ) {
        SimulatorAdvancedMockDataModeStore.setEnabled(false, defaults: defaults)
        SimulatorAdvancedMockDataModeStore.setReferenceDate(nil, defaults: defaults)

        guard scenario != .empty, scenario != .fatigueRegression else { return }

        SimulatorAdvancedMockDataModeStore.setReferenceDate(referenceDate, defaults: defaults)
        SimulatorAdvancedMockDataModeStore.setEnabled(true, defaults: defaults)
    }

    static func weatherSnapshot(for scenario: UITestSeedScenario) -> WeatherSnapshot? {
        switch scenario {
        case .empty, .fatigueRegression:
            nil
        case .defaultSeeded, .activityExerciseSeeded, .notificationRoutingSeeded:
            makeWeatherSnapshot()
        }
    }

    static func sharedHealthSnapshot(
        for scenario: UITestSeedScenario,
        fetchedAt: Date = Date()
    ) -> SharedHealthSnapshot? {
        switch scenario {
        case .empty, .fatigueRegression:
            nil
        case .defaultSeeded, .activityExerciseSeeded, .notificationRoutingSeeded:
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
            distance: 6_200,
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

    /// Opt-in dense Today row fixture. Its title matches a real exercise definition.
    static func todayWorkoutRowFixture() -> [HealthMetric] {
        [HealthMetric(
            id: "exercise-compact-row",
            name: String(localized: "Seated Cable Row"),
            value: 34,
            unit: "min",
            change: nil,
            date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            category: .exercise,
            isHistorical: true,
            iconOverride: "dumbbell.fill",
            workoutTypeKey: "Seated Cable Row"
        ), HealthMetric(
            id: "exercise-compact-run", name: String(localized: "Running"),
            value: 10, unit: "km", change: nil,
            date: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date(),
            category: .exercise, isHistorical: true,
            iconOverride: "figure.run", workoutTypeKey: "Running"
        ), HealthMetric(
            id: "exercise-compact-cycle", name: String(localized: "Cycling"),
            value: 20, unit: "km", change: nil,
            date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            category: .exercise, isHistorical: true,
            iconOverride: "bicycle", workoutTypeKey: "Cycling"
        )]
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
    private static func seedDefaultRecords(
        into context: ModelContext,
        scenario: UITestSeedScenario = .defaultSeeded
    ) {
        let recordsOnly = ProcessInfo.processInfo.arguments.contains("--uitesting") &&
            ProcessInfo.processInfo.arguments.contains("--ui-test-wellness-records-only")
        configureTodayDefaults()
        if !recordsOnly { seedSharedHealthSnapshot(into: context) }
        seedExerciseDefaults(into: context)
        seedExerciseRecords(into: context)
        if !recordsOnly { seedBodyCompositionRecords(into: context) }
        seedInjuryRecords(into: context)
        seedHabitDefinitions(into: context)
        seedNotificationInbox(scenario: scenario)
        if ProcessInfo.processInfo.arguments.contains("--ui-hero-rhythm-fixtures") {
            seedHeroRhythmHistory(into: context)
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-workout-board-goal-fixture") {
            let goal = HabitDefinition(
                name: "Weekly Move",
                iconCategory: .fitness,
                habitType: .check,
                goalValue: 1,
                goalUnit: nil,
                frequency: .daily,
                sortOrder: 3
            )
            goal.isAutoLinked = true
            goal.autoLinkSourceRaw = "exercise"
            context.insert(goal)
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-hero-rhythm-auto-only") {
            let habits = (try? context.fetch(FetchDescriptor<HabitDefinition>())) ?? []
            for habit in habits {
                habit.isAutoLinked = true
                habit.autoLinkSourceRaw = "exercise"
            }
        }
        if recordsOnly || ProcessInfo.processInfo.arguments.contains("--ui-visual-posture-fixtures") {
            seedVisualPostureFixtures(into: context)
        }
        try? context.save()
    }

    /// Opt-in recorded history for Activity/Life hero UI checks. Normal seeded
    /// launches keep their existing sparse-history semantics.
    @MainActor
    private static func seedHeroRhythmHistory(into context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for (daysAgo, score) in [(2, 68.0), (5, 82.0)] {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today),
                  let midday = calendar.date(byAdding: .hour, value: 12, to: day) else { continue }
            context.insert(HourlyScoreSnapshot(date: midday, readinessScore: score))
        }

        let descriptor = FetchDescriptor<HabitDefinition>()
        guard let habits = try? context.fetch(descriptor) else { return }
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        for habit in habits { habit.createdAt = start }
        for (daysAgo, names) in [(1, ["Morning Stretch", "Read"]), (3, ["Morning Stretch"])] {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            for habit in habits where names.contains(habit.name) {
                let log = HabitLog(date: day, value: habit.goalValue, completedAt: day)
                context.insert(log)
                log.habitDefinition = habit
            }
        }
    }

    /// Synthetic records for visual inspection only; no camera or health inference.
    @MainActor
    private static func seedVisualPostureFixtures(into context: ModelContext) {
        // A system symbol is deliberately not a real body photo. This fixture
        // exercises image-present routes, not photographic analysis quality.
        let placeholder = UIImage(systemName: "figure.stand")?.pngData()
        let joints = [
            JointPosition3D(name: "leftShoulder", x: -0.2, y: 0.5, z: 0),
            JointPosition3D(name: "rightShoulder", x: 0.2, y: 0.48, z: 0),
            JointPosition3D(name: "leftHip", x: -0.15, y: 0, z: 0),
            JointPosition3D(name: "rightHip", x: 0.15, y: -0.01, z: 0),
            JointPosition3D(name: "leftKnee", x: -0.12, y: -0.45, z: 0),
            JointPosition3D(name: "rightKnee", x: 0.14, y: -0.45, z: 0),
            JointPosition3D(name: "leftAnkle", x: -0.15, y: -0.85, z: 0),
            JointPosition3D(name: "rightAnkle", x: 0.15, y: -0.85, z: 0)
        ]
        for offset in [14, 1] {
            let metrics = PostureMetricType.allCases.enumerated().map { index, type in
                PostureMetricResult(
                    type: type,
                    value: Double(index + offset),
                    unit: .degrees,
                    status: index.isMultiple(of: 2) ? .caution : .normal,
                    score: 90 - offset - index,
                    confidence: 0.9
                )
            }
            context.insert(PostureAssessmentRecord(
                date: Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date(),
                overallScore: metrics.weightedOverallScore(),
                frontMetrics: metrics.filter { !$0.type.requiresSideView },
                sideMetrics: metrics.filter { $0.type.requiresSideView },
                frontJointPositions: joints,
                frontImageData: placeholder,
                sideImageData: placeholder,
                bodyHeight: 175,
                memo: "Visual audit fixture — synthetic measurements for layout verification. "
                    + String(repeating: "Long memo wrapping and scrolling. ", count: 8)
            ))
        }
    }

    @MainActor
    private static func seedFatigueRegression(into context: ModelContext) {
        let now = Date()
        let weights = [85.0, 90, 85, 85, 80, 75, 70, 70, 65, 65]
        let sessions = [(hours: 149.0, reps: [10, 8, 8, 8, 8, 8, 8, 8, 8, 6]),
                        (hours: 317.1, reps: [10, 8, 8, 6, 8, 6, 6, 6, 8, 6])]
        for session in sessions {
            let record = ExerciseRecord(
                date: now.addingTimeInterval(-session.hours * 3600),
                exerciseType: "strength", duration: 18 * 60,
                exerciseDefinitionID: "chest-press-machine",
                primaryMuscles: [.chest], equipment: .machine
            )
            context.insert(record)
            record.sets = zip(weights, session.reps).enumerated().map { index, values in
                let set = WorkoutSet(setNumber: index + 1, weight: values.0,
                                     reps: values.1, isCompleted: true)
                set.exerciseRecord = record
                context.insert(set)
                return set
            }
        }
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to seed fatigue regression: \(error)")
        }
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
        if let workout = mockWorkoutSummary(
            for: .activityExerciseSeeded,
            workoutID: activityExerciseMockWorkoutID
        ) {
            _ = PersonalRecordStore.shared.evaluateReward(for: workout, newPRTypes: [.fastestPace])
        }
        try? context.save()
    }

    /// Opt-in UI-only locations. The square course is synthetic and never presented as a user's GPS history.
    @MainActor
    private static func seedCardioAtlasFixtures(into context: ModelContext) {
        let now = Date()
        let start = now.addingTimeInterval(-1_800)
        let course: [(Double, Double)] = [
            (37.5465, 127.0415), (37.54875, 127.0415), (37.5510, 127.0415),
            (37.5510, 127.0443), (37.5510, 127.0471),
            (37.54875, 127.0471), (37.5465, 127.0471),
            (37.5465, 127.0443), (37.5465, 127.0415)
        ]
        // Realistic sampling cadence: sparse corner-only points would correctly be split
        // into isolated segments by the production gap filter and could not test a route.
        var route: [WorkoutRoutePoint] = []
        for index in 0...160 {
            let leg = min(index / 20, course.count - 2)
            let fraction = Double(index - leg * 20) / 20
            let from = course[leg]
            let to = course[leg + 1]
            let elapsed = Double(index * 8 + (index >= 81 ? 60 : 0))
            if let point = WorkoutRoutePoint(
                latitude: from.0 + (to.0 - from.0) * fraction,
                longitude: from.1 + (to.1 - from.1) * fraction,
                timestamp: start.addingTimeInterval(elapsed),
                horizontalAccuracy: 8,
                startsNewSegment: index == 0 || index == 81
            ) {
                route.append(point)
            }
        }
        let run = ExerciseRecord(
            date: start, exerciseType: "Atlas Route Run",
            duration: 1_280, calories: 210, distance: 2.0,
            exerciseDefinitionID: "running"
        )
        context.insert(run)
        context.insert(WorkoutLocationRecord(
            localRecordID: run.id,
            payload: WorkoutLocationPayload(isIndoor: false, route: route)
        ))

        let elliptical = ExerciseRecord(
            date: now.addingTimeInterval(-3_600), exerciseType: "Atlas Indoor Cardio",
            duration: 1_200, calories: 180, exerciseDefinitionID: "elliptical"
        )
        context.insert(elliptical)
        let place = WorkoutPlace(
            latitude: 37.5445, longitude: 127.0438,
            name: "Atlas Indoor Gym (UI Fixture)", source: .manual
        )
        context.insert(WorkoutLocationRecord(
            localRecordID: elliptical.id,
            payload: WorkoutLocationPayload(isIndoor: true, place: place)
        ))

        let unlocated = ExerciseRecord(
            date: now.addingTimeInterval(-7_200), exerciseType: "Atlas Unlocated Cardio",
            duration: 900, exerciseDefinitionID: "rowing-machine"
        )
        context.insert(unlocated)

        do {
            try context.save()
        } catch {
            assertionFailure("Failed to seed Cardio Atlas UI fixtures: \(error)")
        }
    }

    @MainActor
    private static func seedExerciseDefaults(into context: ModelContext) {
        let benchPressDefault = ExerciseDefaultRecord(
            exerciseDefinitionID: "barbell-bench-press",
            defaultWeight: 60,
            defaultReps: 8,
            isManualOverride: false,
            isPreferred: false,
            lastUsedDate: Date()
        )
        context.insert(benchPressDefault)
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
                    isCompleted: true,
                    // Opt-in fold evidence must survive XCTest's idle wait
                    // after a real display transition. Normal fixtures retain
                    // the app's default rest behavior.
                    restDuration: ProcessInfo.processInfo.arguments.contains("--ui-fold-audit-long-rest")
                        && exercise.defID == "barbell-bench-press" ? 600 : nil
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

        if scenario == .notificationRoutingSeeded {
            if ProcessInfo.processInfo.arguments.contains("--ui-design-map-notification-details") {
                insights.insert(contentsOf: [
                    HealthInsight(
                        type: .stepGoal,
                        title: "Message Route Fixture",
                        body: "A notification message that opens its in-app detail.",
                        severity: .informational,
                        route: .notificationHub
                    ),
                    HealthInsight(
                        type: .stepGoal,
                        title: "Unavailable Route Fixture",
                        body: "A notification whose destination is unavailable.",
                        severity: .informational,
                        route: .notificationHub
                    ),
                    HealthInsight(
                        type: .workoutPR,
                        title: "Personal Records Route Fixture",
                        body: "Open personal records from the notification inbox.",
                        severity: .celebration,
                        route: .activityPersonalRecords
                    )
                ], at: 0)
            }
            insights.insert(contentsOf: [
                HealthInsight(
                    type: .sleepComplete,
                    title: "Bedtime Route Fixture",
                    body: "Wear your Apple Watch to bed to track sleep.",
                    severity: .informational,
                    route: .sleepDetail
                ),
                HealthInsight(
                    type: .postureReminder,
                    title: "Posture Route Fixture",
                    body: "Time for a posture check-up.",
                    severity: .informational
                ),
                HealthInsight(
                    type: .dailyDigest,
                    title: "Daily Digest Route Fixture",
                    body: "Review today's summary.",
                    severity: .informational
                ),
                HealthInsight(
                    type: .lifeChecklistReminder,
                    title: "Life Checklist Route Fixture",
                    body: "Review your checklist.",
                    severity: .informational,
                    route: .notificationHub
                )
            ], at: 0)
            return insights
        }

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

        let hourlyConditionHistory = ProcessInfo.processInfo.arguments.contains("--ui-test-condition-hourly-history")
        let hrvSamples: [HRVSample] = (0..<(hourlyConditionHistory ? 22 : 14)).flatMap { offset -> [HRVSample] in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return [] }
            let hours = hourlyConditionHistory ? [7, 8, 9, 10] : [0]
            return hours.compactMap { hour in
                guard let date = calendar.date(byAdding: .hour, value: hour, to: day) else { return nil }
                return HRVSample(value: 66 - Double(offset) + Double(hour) * 0.1, date: date)
            }
        }

        let rhrCollection: [(date: Date, min: Double, max: Double, average: Double)] = (0..<14).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let average = 54 + Double(min(offset, 5))
            return (date: date, min: average - 1, max: average + 1, average: average)
        }

        let sleepDailyDurations: [SharedHealthSnapshot.SleepDailyDuration] = ProcessInfo.processInfo.arguments.contains("--ui-test-no-sleep-trend") ? [] : (0..<14).compactMap { offset in
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

        // Only the opt-in stress audit adds HRV provenance. The normal seed remains unchanged.
        let stressAuditContributions: [ScoreContribution] = ProcessInfo.processInfo.arguments
            .contains("--ui-visual-stress-fixture")
            ? [.init(factor: .hrv, impact: .neutral, detail: "Synthetic visual audit HRV contribution")]
            : []
        let conditionComponentDetail: ConditionScoreDetail? = ProcessInfo.processInfo.arguments
            .contains("--ui-visual-condition-components-fixture")
            ? ConditionScoreDetail(
                todayHRV: 60, baselineHRV: 40, zScore: 2,
                stdDev: 10, effectiveStdDev: 10, daysInBaseline: 14,
                todayDate: today, rawScore: 100, todayRHR: 54,
                baselineRHR: 54, rhrDeltaFromBaseline: 0, rhrBaselineDays: 14
            )
            : nil
        // Opt-in visual boundary fixture; never changes the standard seeded snapshot.
        let arguments = ProcessInfo.processInfo.arguments
        let boundaryScore: Int? = arguments.firstIndex(of: "--ui-condition-score-fixture").flatMap { index in
            guard arguments.indices.contains(index + 1),
                  let score = Int(arguments[index + 1]), (0...100).contains(score) else { return nil }
            return score
        }
        let recentScores: [ConditionScore] = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return ConditionScore(
                score: max(55, 84 - offset * 3),
                date: date,
                contributions: stressAuditContributions
            )
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
            conditionScore: ConditionScore(score: boundaryScore ?? (conditionComponentDetail == nil ? 84 : 100),
                                           date: today, detail: boundaryScore == nil ? conditionComponentDetail : nil),
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
