import Foundation
import SwiftData

enum SimulatorAdvancedMockDataModeStore {
    static let storageKey = "simulatorAdvancedMockDataEnabled"
    static let referenceDateStorageKey = "simulatorAdvancedMockDataReferenceDate"

    static var isSimulatorAvailable: Bool {
#if targetEnvironment(simulator)
        true
#else
        false
#endif
    }

    static var isEnabled: Bool {
        isSimulatorAvailable && UserDefaults.standard.bool(forKey: storageKey)
    }

    static var referenceDate: Date? {
        guard isSimulatorAvailable else { return nil }
        let interval = UserDefaults.standard.double(forKey: referenceDateStorageKey)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        guard isSimulatorAvailable else { return }
        defaults.set(enabled, forKey: storageKey)
    }

    static func setReferenceDate(_ date: Date?, defaults: UserDefaults = .standard) {
        guard isSimulatorAvailable else { return }
        if let date {
            defaults.set(date.timeIntervalSince1970, forKey: referenceDateStorageKey)
        } else {
            defaults.removeObject(forKey: referenceDateStorageKey)
        }
    }
}

extension Notification.Name {
    static let simulatorAdvancedMockDataDidChange = Notification.Name(
        "simulatorAdvancedMockDataDidChange"
    )
}

struct SimulatorAdvancedMockWorkout: Sendable {
    let summary: WorkoutSummary
    let heartRateSamples: [HeartRateSample]
}

struct SimulatorAdvancedMockVitals: Sendable {
    let oxygenSaturation: [VitalSample]
    let respiratoryRate: [VitalSample]
    let vo2Max: [VitalSample]
    let heartRateRecovery: [VitalSample]
    let wristTemperature: [VitalSample]
    let generalHeartRate: [VitalSample]
}

struct SimulatorAdvancedMockDataSet: Sendable {
    let referenceDate: Date
    let sharedHealthSnapshot: SharedHealthSnapshot
    let workouts: [SimulatorAdvancedMockWorkout]
    let weightSamples: [BodyCompositionSample]
    let bodyFatSamples: [BodyCompositionSample]
    let leanBodyMassSamples: [BodyCompositionSample]
    let bmiSamples: [BodyCompositionSample]
    let stepsCollection: [(date: Date, sum: Double)]
    let vitals: SimulatorAdvancedMockVitals

    func workoutSummaries(start: Date, end: Date) -> [WorkoutSummary] {
        workouts
            .map(\.summary)
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date > $1.date }
    }

    func workout(withID workoutID: String) -> SimulatorAdvancedMockWorkout? {
        workouts.first { $0.summary.id == workoutID }
    }

    func hrvSamples(days: Int) -> [HRVSample] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: referenceDate) ?? referenceDate
        return sharedHealthSnapshot.hrvSamples
            .filter { $0.date >= cutoff && $0.date <= referenceDate }
            .sorted { $0.date > $1.date }
    }

    func restingHeartRate(for date: Date) -> Double? {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: referenceDate) {
            return sharedHealthSnapshot.todayRHR ?? sharedHealthSnapshot.latestRHR?.value
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return sharedHealthSnapshot.yesterdayRHR ?? sharedHealthSnapshot.latestRHR?.value
        }
        return sharedHealthSnapshot.rhrCollection.first {
            calendar.isDate($0.date, inSameDayAs: date)
        }?.average
    }

    func latestRestingHeartRate(withinDays days: Int) -> (value: Double, date: Date)? {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -days, to: referenceDate) ?? referenceDate

        let samples: [(date: Date, value: Double)] = sharedHealthSnapshot.rhrCollection.compactMap { sample in
            guard sample.date >= cutoff && sample.date <= referenceDate else { return nil }
            return (date: sample.date, value: sample.average)
        }

        if let latest = samples.sorted(by: { $0.date > $1.date }).first {
            return (value: latest.value, date: latest.date)
        }

        if let todayRHR = sharedHealthSnapshot.todayRHR {
            return (value: todayRHR, date: calendar.startOfDay(for: referenceDate))
        }

        return sharedHealthSnapshot.latestRHR.map { (value: $0.value, date: $0.date) }
    }

    func rhrCollection(start: Date, end: Date) -> [(date: Date, min: Double, max: Double, average: Double)] {
        sharedHealthSnapshot.rhrCollection
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }
    }

    func sleepStages(for date: Date) -> [SleepStage] {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: referenceDate) {
            return sharedHealthSnapshot.todaySleepStages
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return sharedHealthSnapshot.yesterdaySleepStages
        }
        return []
    }

    func latestSleepStages(withinDays days: Int) -> (stages: [SleepStage], date: Date)? {
        let calendar = Calendar.current

        if !sharedHealthSnapshot.todaySleepStages.filter({ $0.stage != .awake }).isEmpty {
            return (
                stages: sharedHealthSnapshot.todaySleepStages,
                date: calendar.startOfDay(for: referenceDate)
            )
        }

        if !sharedHealthSnapshot.yesterdaySleepStages.filter({ $0.stage != .awake }).isEmpty,
           let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate),
           yesterday >= (calendar.date(byAdding: .day, value: -days, to: referenceDate) ?? referenceDate) {
            return (
                stages: sharedHealthSnapshot.yesterdaySleepStages,
                date: calendar.startOfDay(for: yesterday)
            )
        }

        return sharedHealthSnapshot.latestSleepStages.map { (stages: $0.stages, date: $0.date) }
    }

    func sleepDailyDurations(start: Date, end: Date) -> [SharedHealthSnapshot.SleepDailyDuration] {
        sharedHealthSnapshot.sleepDailyDurations
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }
    }

    func weightSamples(start: Date, end: Date) -> [BodyCompositionSample] {
        filterSamples(weightSamples, start: start, end: end)
    }

    func bodyFatSamples(start: Date, end: Date) -> [BodyCompositionSample] {
        filterSamples(bodyFatSamples, start: start, end: end)
    }

    func leanBodyMassSamples(start: Date, end: Date) -> [BodyCompositionSample] {
        filterSamples(leanBodyMassSamples, start: start, end: end)
    }

    func bmiSamples(start: Date, end: Date) -> [BodyCompositionSample] {
        filterSamples(bmiSamples, start: start, end: end)
    }

    func latestWeight(withinDays days: Int) -> (value: Double, date: Date)? {
        latestBodySample(in: weightSamples, withinDays: days)
    }

    func latestBodyFat(withinDays days: Int) -> (value: Double, date: Date)? {
        latestBodySample(in: bodyFatSamples, withinDays: days)
    }

    func latestLeanBodyMass(withinDays days: Int) -> (value: Double, date: Date)? {
        latestBodySample(in: leanBodyMassSamples, withinDays: days)
    }

    func latestBMI(withinDays days: Int) -> (value: Double, date: Date)? {
        latestBodySample(in: bmiSamples, withinDays: days)
    }

    func bmi(for date: Date) -> Double? {
        let targetDay = Calendar.current.startOfDay(for: date)
        return bmiSamples.first {
            Calendar.current.isDate($0.date, inSameDayAs: targetDay)
        }?.value
    }

    func steps(for date: Date) -> Double? {
        stepsCollection.first {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }?.sum
    }

    func latestSteps(withinDays days: Int) -> (value: Double, date: Date)? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: referenceDate) ?? referenceDate
        return stepsCollection
            .filter { $0.date >= cutoff && $0.date < referenceDate }
            .sorted { $0.date > $1.date }
            .first
            .map { (value: $0.sum, date: $0.date) }
    }

    func stepsCollection(start: Date, end: Date) -> [(date: Date, sum: Double)] {
        stepsCollection
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }
    }

    func latestHeartRate(withinDays days: Int) -> VitalSample? {
        latestVital(in: vitals.generalHeartRate, withinDays: days)
    }

    func heartRateHistory(start: Date, end: Date) -> [VitalSample] {
        filterSamples(vitals.generalHeartRate, start: start, end: end)
    }

    func latestSpO2(withinDays days: Int) -> VitalSample? {
        latestVital(in: vitals.oxygenSaturation, withinDays: days)
    }

    func latestRespiratoryRate(withinDays days: Int) -> VitalSample? {
        latestVital(in: vitals.respiratoryRate, withinDays: days)
    }

    func latestVO2Max(withinDays days: Int) -> VitalSample? {
        latestVital(in: vitals.vo2Max, withinDays: days)
    }

    func latestHeartRateRecovery(withinDays days: Int) -> VitalSample? {
        latestVital(in: vitals.heartRateRecovery, withinDays: days)
    }

    func latestWristTemperature(withinDays days: Int) -> VitalSample? {
        latestVital(in: vitals.wristTemperature, withinDays: days)
    }

    func oxygenSaturation(start: Date, end: Date) -> [VitalSample] {
        filterSamples(vitals.oxygenSaturation, start: start, end: end)
    }

    func respiratoryRate(start: Date, end: Date) -> [VitalSample] {
        filterSamples(vitals.respiratoryRate, start: start, end: end)
    }

    func vo2Max(start: Date, end: Date) -> [VitalSample] {
        filterSamples(vitals.vo2Max, start: start, end: end)
    }

    func heartRateRecovery(start: Date, end: Date) -> [VitalSample] {
        filterSamples(vitals.heartRateRecovery, start: start, end: end)
    }

    func wristTemperature(start: Date, end: Date) -> [VitalSample] {
        filterSamples(vitals.wristTemperature, start: start, end: end)
    }

    private func latestBodySample(
        in samples: [BodyCompositionSample],
        withinDays days: Int
    ) -> (value: Double, date: Date)? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: referenceDate) ?? referenceDate
        guard let sample = samples.first(where: { $0.date >= cutoff && $0.date < referenceDate }) else {
            return nil
        }
        return (value: sample.value, date: sample.date)
    }

    private func latestVital(
        in samples: [VitalSample],
        withinDays days: Int
    ) -> VitalSample? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: referenceDate) ?? referenceDate
        return samples.first { $0.date >= cutoff && $0.date < referenceDate }
    }

    private func filterSamples<T>(
        _ samples: [T],
        start: Date,
        end: Date,
        date: (T) -> Date
    ) -> [T] {
        samples
            .filter {
                let sampleDate = date($0)
                return sampleDate >= start && sampleDate < end
            }
            .sorted { date($0) < date($1) }
    }

    private func filterSamples(
        _ samples: [BodyCompositionSample],
        start: Date,
        end: Date
    ) -> [BodyCompositionSample] {
        filterSamples(samples, start: start, end: end, date: \.date)
    }

    private func filterSamples(
        _ samples: [VitalSample],
        start: Date,
        end: Date
    ) -> [VitalSample] {
        filterSamples(samples, start: start, end: end, date: \.date)
    }
}

enum SimulatorAdvancedMockDataProvider {
    static func current(referenceDate: Date = Date()) -> SimulatorAdvancedMockDataSet? {
        guard SimulatorAdvancedMockDataModeStore.isEnabled else { return nil }
        return buildDataSet(
            referenceDate: SimulatorAdvancedMockDataModeStore.referenceDate ?? referenceDate
        )
    }

    @MainActor
    static func seed(into context: ModelContext, referenceDate: Date = Date()) throws {
        guard SimulatorAdvancedMockDataModeStore.isSimulatorAvailable else { return }
        let dataSet = buildDataSet(referenceDate: referenceDate)
        try deletePersistedData(from: context)
        persist(dataSet: dataSet, into: context)
        try context.save()
        SimulatorAdvancedMockDataModeStore.setReferenceDate(dataSet.referenceDate)
        SimulatorAdvancedMockDataModeStore.setEnabled(true)
        postDidChangeNotification()
    }

    @MainActor
    static func reset(into context: ModelContext) throws {
        guard SimulatorAdvancedMockDataModeStore.isSimulatorAvailable else { return }
        try deletePersistedData(from: context)
        try context.save()
        SimulatorAdvancedMockDataModeStore.setReferenceDate(nil)
        SimulatorAdvancedMockDataModeStore.setEnabled(false)
        postDidChangeNotification()
    }

    static func postDidChangeNotification() {
        NotificationCenter.default.post(name: .simulatorAdvancedMockDataDidChange, object: nil)
    }

    private static func buildDataSet(referenceDate: Date) -> SimulatorAdvancedMockDataSet {
        let snapshot = buildSharedHealthSnapshot(referenceDate: referenceDate)
        let workouts = buildWorkouts(referenceDate: referenceDate)
        let weightSamples = buildBodyCompositionSeries(
            referenceDate: referenceDate,
            base: 78.4,
            step: -0.12,
            count: 16
        )
        let bodyFatSamples = buildBodyCompositionSeries(
            referenceDate: referenceDate,
            base: 17.8,
            step: -0.08,
            count: 16
        )
        let leanBodyMassSamples = buildBodyCompositionSeries(
            referenceDate: referenceDate,
            base: 63.1,
            step: 0.09,
            count: 16
        )
        let bmiSamples = weightSamples.map {
            BodyCompositionSample(
                value: ($0.value / (1.78 * 1.78)).rounded(toPlaces: 1),
                date: $0.date
            )
        }
        let stepsCollection = buildStepsCollection(referenceDate: referenceDate)
        let vitals = buildVitals(referenceDate: referenceDate)

        return SimulatorAdvancedMockDataSet(
            referenceDate: referenceDate,
            sharedHealthSnapshot: snapshot,
            workouts: workouts,
            weightSamples: weightSamples,
            bodyFatSamples: bodyFatSamples,
            leanBodyMassSamples: leanBodyMassSamples,
            bmiSamples: bmiSamples,
            stepsCollection: stepsCollection,
            vitals: vitals
        )
    }

    private static func buildSharedHealthSnapshot(referenceDate: Date) -> SharedHealthSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)

        let hrvSamples: [HRVSample] = (0..<30).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let drift = Double((offset % 5) - 2) * 1.4
            let value = 78 - Double(offset) * 0.55 + drift
            return HRVSample(value: max(42, value), date: date)
        }

        let rhrCollection: [(date: Date, min: Double, max: Double, average: Double)] = (0..<30).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let average = 50 + Double(min(offset, 8)) * 0.6 + Double(offset % 3)
            return (date: date, min: average - 2, max: average + 3, average: average)
        }

        let sleepDailyDurations: [SharedHealthSnapshot.SleepDailyDuration] = (0..<30).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let deep = max(74, 104 - Double(offset % 6) * 4)
            let rem = max(86, 112 - Double(offset % 5) * 3)
            let core = max(210, 258 - Double(offset % 7) * 5)
            let awake = 14 + Double(offset % 4) * 2
            return SharedHealthSnapshot.SleepDailyDuration(
                date: date,
                totalMinutes: deep + rem + core,
                stageBreakdown: [
                    .deep: deep,
                    .rem: rem,
                    .core: core,
                    .awake: awake
                ]
            )
        }

        let recentScores: [ConditionScore] = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return ConditionScore(score: max(66, 90 - offset * 2), date: date)
        }

        let todaySleepStages = buildSleepStages(
            startOfDay: today,
            deepMinutes: 104,
            remMinutes: 110,
            coreMinutes: 252,
            awakeMinutes: 18
        )
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let yesterdaySleepStages = buildSleepStages(
            startOfDay: yesterday,
            deepMinutes: 97,
            remMinutes: 108,
            coreMinutes: 244,
            awakeMinutes: 16
        )

        return SharedHealthSnapshot(
            hrvSamples: hrvSamples,
            todayRHR: 50,
            yesterdayRHR: 52,
            latestRHR: nil,
            rhrCollection: rhrCollection,
            todaySleepStages: todaySleepStages,
            yesterdaySleepStages: yesterdaySleepStages,
            latestSleepStages: nil,
            sleepDailyDurations: sleepDailyDurations,
            conditionScore: ConditionScore(score: 90, date: today),
            baselineStatus: nil,
            recentConditionScores: recentScores,
            failedSources: [],
            fetchedAt: referenceDate
        )
    }

    private static func buildWorkouts(referenceDate: Date) -> [SimulatorAdvancedMockWorkout] {
        let calendar = Calendar.current

        struct Descriptor {
            let id: String
            let title: String
            let activityType: WorkoutActivityType
            let daysAgo: Int
            let durationMinutes: Double
            let calories: Double
            let distanceMeters: Double?
            let averagePace: Double?
            let averageSpeed: Double?
            let elevation: Double?
            let weatherTemperature: Double?
            let weatherCondition: Int?
            let weatherHumidity: Double?
            let isIndoor: Bool
            let effortScore: Double
            let stepCount: Double?
            let flightsClimbed: Double?
            let averageHeartRate: Double
            let maxHeartRate: Double
            let minHeartRate: Double
            let milestoneDistance: MilestoneDistance?
            let personalRecordTypes: [PersonalRecordType]
        }

        let descriptors: [Descriptor] = [
            .init(
                id: "mock-workout-running-tempo",
                title: "Tempo Run",
                activityType: .running,
                daysAgo: 1,
                durationMinutes: 48,
                calories: 612,
                distanceMeters: 10_200,
                averagePace: 282,
                averageSpeed: 3.55,
                elevation: 74,
                weatherTemperature: 11,
                weatherCondition: 1,
                weatherHumidity: 48,
                isIndoor: false,
                effortScore: 8.4,
                stepCount: 10_982,
                flightsClimbed: 11,
                averageHeartRate: 154,
                maxHeartRate: 178,
                minHeartRate: 98,
                milestoneDistance: .tenK,
                personalRecordTypes: [.fastestPace]
            ),
            .init(
                id: "mock-workout-strength-upper",
                title: "Upper Strength",
                activityType: .traditionalStrengthTraining,
                daysAgo: 2,
                durationMinutes: 78,
                calories: 486,
                distanceMeters: nil,
                averagePace: nil,
                averageSpeed: nil,
                elevation: nil,
                weatherTemperature: nil,
                weatherCondition: nil,
                weatherHumidity: nil,
                isIndoor: true,
                effortScore: 8.0,
                stepCount: 2_610,
                flightsClimbed: 3,
                averageHeartRate: 128,
                maxHeartRate: 162,
                minHeartRate: 76,
                milestoneDistance: nil,
                personalRecordTypes: [.highestCalories]
            ),
            .init(
                id: "mock-workout-cycling-long",
                title: "Long Ride",
                activityType: .cycling,
                daysAgo: 4,
                durationMinutes: 92,
                calories: 801,
                distanceMeters: 34_600,
                averagePace: nil,
                averageSpeed: 6.27,
                elevation: 312,
                weatherTemperature: 14,
                weatherCondition: 2,
                weatherHumidity: 54,
                isIndoor: false,
                effortScore: 7.7,
                stepCount: nil,
                flightsClimbed: 0,
                averageHeartRate: 146,
                maxHeartRate: 171,
                minHeartRate: 90,
                milestoneDistance: nil,
                personalRecordTypes: [.longestDuration]
            ),
            .init(
                id: "mock-workout-stairs-threshold",
                title: "Stair Threshold",
                activityType: .stairStepper,
                daysAgo: 6,
                durationMinutes: 36,
                calories: 421,
                distanceMeters: nil,
                averagePace: nil,
                averageSpeed: nil,
                elevation: 186,
                weatherTemperature: nil,
                weatherCondition: nil,
                weatherHumidity: nil,
                isIndoor: true,
                effortScore: 8.7,
                stepCount: 4_802,
                flightsClimbed: 58,
                averageHeartRate: 158,
                maxHeartRate: 182,
                minHeartRate: 104,
                milestoneDistance: nil,
                personalRecordTypes: [.highestElevation]
            ),
            .init(
                id: "mock-workout-swim-technique",
                title: "Pool Intervals",
                activityType: .swimming,
                daysAgo: 8,
                durationMinutes: 44,
                calories: 398,
                distanceMeters: 2_400,
                averagePace: 110,
                averageSpeed: 0.91,
                elevation: nil,
                weatherTemperature: nil,
                weatherCondition: nil,
                weatherHumidity: nil,
                isIndoor: true,
                effortScore: 7.0,
                stepCount: nil,
                flightsClimbed: nil,
                averageHeartRate: 138,
                maxHeartRate: 161,
                minHeartRate: 82,
                milestoneDistance: nil,
                personalRecordTypes: []
            ),
            .init(
                id: "mock-workout-hike-ridge",
                title: "Ridge Hike",
                activityType: .hiking,
                daysAgo: 11,
                durationMinutes: 128,
                calories: 730,
                distanceMeters: 12_800,
                averagePace: 600,
                averageSpeed: 1.67,
                elevation: 644,
                weatherTemperature: 9,
                weatherCondition: 3,
                weatherHumidity: 61,
                isIndoor: false,
                effortScore: 7.9,
                stepCount: 16_220,
                flightsClimbed: 104,
                averageHeartRate: 134,
                maxHeartRate: 160,
                minHeartRate: 81,
                milestoneDistance: .tenK,
                personalRecordTypes: []
            ),
            .init(
                id: "mock-workout-running-pr",
                title: "Track Session",
                activityType: .running,
                daysAgo: 15,
                durationMinutes: 34,
                calories: 410,
                distanceMeters: 8_000,
                averagePace: 255,
                averageSpeed: 3.92,
                elevation: 18,
                weatherTemperature: 13,
                weatherCondition: 1,
                weatherHumidity: 42,
                isIndoor: false,
                effortScore: 9.0,
                stepCount: 8_934,
                flightsClimbed: 4,
                averageHeartRate: 162,
                maxHeartRate: 186,
                minHeartRate: 100,
                milestoneDistance: .fiveK,
                personalRecordTypes: [.fastestPace, .longestDistance]
            ),
            .init(
                id: "mock-workout-strength-lower",
                title: "Lower Strength",
                activityType: .functionalStrengthTraining,
                daysAgo: 18,
                durationMinutes: 72,
                calories: 502,
                distanceMeters: nil,
                averagePace: nil,
                averageSpeed: nil,
                elevation: nil,
                weatherTemperature: nil,
                weatherCondition: nil,
                weatherHumidity: nil,
                isIndoor: true,
                effortScore: 8.3,
                stepCount: 2_942,
                flightsClimbed: 2,
                averageHeartRate: 132,
                maxHeartRate: 166,
                minHeartRate: 74,
                milestoneDistance: nil,
                personalRecordTypes: []
            ),
            .init(
                id: "mock-workout-walk-recovery",
                title: "Recovery Walk",
                activityType: .walking,
                daysAgo: 21,
                durationMinutes: 56,
                calories: 254,
                distanceMeters: 5_100,
                averagePace: 658,
                averageSpeed: 1.52,
                elevation: 36,
                weatherTemperature: 12,
                weatherCondition: 2,
                weatherHumidity: 52,
                isIndoor: false,
                effortScore: 4.2,
                stepCount: 6_874,
                flightsClimbed: 7,
                averageHeartRate: 104,
                maxHeartRate: 122,
                minHeartRate: 70,
                milestoneDistance: .fiveK,
                personalRecordTypes: []
            ),
            .init(
                id: "mock-workout-rowing-engine",
                title: "Rowing Engine",
                activityType: .rowing,
                daysAgo: 25,
                durationMinutes: 40,
                calories: 364,
                distanceMeters: 9_300,
                averagePace: nil,
                averageSpeed: 3.88,
                elevation: nil,
                weatherTemperature: nil,
                weatherCondition: nil,
                weatherHumidity: nil,
                isIndoor: true,
                effortScore: 7.4,
                stepCount: nil,
                flightsClimbed: nil,
                averageHeartRate: 144,
                maxHeartRate: 167,
                minHeartRate: 84,
                milestoneDistance: nil,
                personalRecordTypes: []
            )
        ]

        return descriptors.compactMap { descriptor in
            guard let date = calendar.date(byAdding: .day, value: -descriptor.daysAgo, to: referenceDate) else {
                return nil
            }

            let summary = WorkoutSummary(
                id: descriptor.id,
                type: descriptor.title,
                activityType: descriptor.activityType,
                duration: descriptor.durationMinutes * 60,
                calories: descriptor.calories,
                distance: descriptor.distanceMeters,
                date: date,
                isFromThisApp: false,
                heartRateAvg: descriptor.averageHeartRate,
                heartRateMax: descriptor.maxHeartRate,
                heartRateMin: descriptor.minHeartRate,
                averagePace: descriptor.averagePace,
                averageSpeed: descriptor.averageSpeed,
                elevationAscended: descriptor.elevation,
                weatherTemperature: descriptor.weatherTemperature,
                weatherCondition: descriptor.weatherCondition,
                weatherHumidity: descriptor.weatherHumidity,
                isIndoor: descriptor.isIndoor,
                effortScore: descriptor.effortScore,
                stepCount: descriptor.stepCount,
                flightsClimbed: descriptor.flightsClimbed,
                milestoneDistance: descriptor.milestoneDistance,
                isPersonalRecord: !descriptor.personalRecordTypes.isEmpty,
                personalRecordTypes: descriptor.personalRecordTypes
            )

            return SimulatorAdvancedMockWorkout(
                summary: summary,
                heartRateSamples: buildHeartRateSamples(
                    startDate: date,
                    duration: summary.duration,
                    minBPM: descriptor.minHeartRate,
                    averageBPM: descriptor.averageHeartRate,
                    maxBPM: descriptor.maxHeartRate
                )
            )
        }
        .sorted { $0.summary.date > $1.summary.date }
    }

    private static func buildVitals(referenceDate: Date) -> SimulatorAdvancedMockVitals {
        let oxygenSaturation = buildVitalSeries(
            referenceDate: referenceDate,
            base: 0.981,
            step: -0.0008,
            count: 18
        )
        let respiratoryRate = buildVitalSeries(
            referenceDate: referenceDate,
            base: 14.2,
            step: 0.1,
            count: 18
        )
        let vo2Max = buildVitalSeries(
            referenceDate: referenceDate,
            base: 48.6,
            step: -0.18,
            count: 12
        )
        let heartRateRecovery = buildVitalSeries(
            referenceDate: referenceDate,
            base: 31,
            step: 0.2,
            count: 12
        )
        let wristTemperature = buildVitalSeries(
            referenceDate: referenceDate,
            base: 36.52,
            step: -0.01,
            count: 18
        )
        let generalHeartRate = buildVitalSeries(
            referenceDate: referenceDate,
            base: 67,
            step: 0.15,
            count: 18
        )

        return SimulatorAdvancedMockVitals(
            oxygenSaturation: oxygenSaturation,
            respiratoryRate: respiratoryRate,
            vo2Max: vo2Max,
            heartRateRecovery: heartRateRecovery,
            wristTemperature: wristTemperature,
            generalHeartRate: generalHeartRate
        )
    }

    private static func buildStepsCollection(referenceDate: Date) -> [(date: Date, sum: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        return (0..<35).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let value = 8_200 + Double((offset % 6) * 580) - Double(offset * 45)
            return (date: date, sum: max(4_200, value))
        }
    }

    private static func buildBodyCompositionSeries(
        referenceDate: Date,
        base: Double,
        step: Double,
        count: Int
    ) -> [BodyCompositionSample] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: referenceDate)
        return (0..<count).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: -(index * 2), to: start) else {
                return nil
            }
            let wave = Double((index % 3) - 1) * abs(step) * 0.5
            return BodyCompositionSample(value: base + Double(index) * step + wave, date: date)
        }
        .sorted { $0.date > $1.date }
    }

    private static func buildVitalSeries(
        referenceDate: Date,
        base: Double,
        step: Double,
        count: Int
    ) -> [VitalSample] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: referenceDate)
        return (0..<count).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: -(index * 2), to: start) else {
                return nil
            }
            let wave = Double((index % 4) - 2) * abs(step) * 0.6
            return VitalSample(value: base + Double(index) * step + wave, date: date)
        }
        .sorted { $0.date > $1.date }
    }

    private static func buildSleepStages(
        startOfDay: Date,
        deepMinutes: Double,
        remMinutes: Double,
        coreMinutes: Double,
        awakeMinutes: Double
    ) -> [SleepStage] {
        let start = startOfDay.addingTimeInterval(60 * 60)
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

    private static func buildHeartRateSamples(
        startDate: Date,
        duration: TimeInterval,
        minBPM: Double,
        averageBPM: Double,
        maxBPM: Double
    ) -> [HeartRateSample] {
        let bucketCount = max(24, Int(duration / 90))
        let interval = duration / Double(bucketCount)

        return (0..<bucketCount).map { index in
            let progress = Double(index) / Double(max(bucketCount - 1, 1))
            let arc = sin(progress * .pi)
            let pulse = sin(progress * .pi * 5) * 4
            let baseline = minBPM + (averageBPM - minBPM) * 0.55
            let peak = (maxBPM - baseline) * arc
            return HeartRateSample(
                bpm: max(minBPM, min(maxBPM, baseline + peak + pulse)),
                date: startDate.addingTimeInterval(interval * Double(index))
            )
        }
    }

    @MainActor
    private static func deletePersistedData(from context: ModelContext) throws {
        try deleteAll(HealthSnapshotMirrorRecord.self, from: context)
#if os(iOS)
        try deleteAll(ExerciseRecord.self, from: context)
        try deleteAll(WorkoutSet.self, from: context)
        try deleteAll(BodyCompositionRecord.self, from: context)
        try deleteAll(CustomExercise.self, from: context)
        try deleteAll(WorkoutTemplate.self, from: context)
        try deleteAll(UserCategory.self, from: context)
#endif
    }

    @MainActor
    private static func persist(
        dataSet: SimulatorAdvancedMockDataSet,
        into context: ModelContext
    ) {
        let payload = HealthSnapshotMirrorMapper.makePayload(from: dataSet.sharedHealthSnapshot)
        if let payloadJSON = try? HealthSnapshotMirrorMapper.encode(payload) {
            context.insert(
                HealthSnapshotMirrorRecord(
                    fetchedAt: dataSet.referenceDate,
                    syncedAt: dataSet.referenceDate,
                    sourceDevice: "SimulatorMock",
                    payloadVersion: 1,
                    payloadJSON: payloadJSON
                )
            )
        }

#if os(iOS)
        for index in stride(from: 0, to: dataSet.weightSamples.count, by: 2) {
            let weightSample = dataSet.weightSamples[index]
            let bodyFatSample = dataSet.bodyFatSamples[index]
            let leanMassSample = dataSet.leanBodyMassSamples[index]
            context.insert(
                BodyCompositionRecord(
                    date: weightSample.date,
                    weight: weightSample.value,
                    bodyFatPercentage: bodyFatSample.value,
                    muscleMass: leanMassSample.value,
                    memo: "Advanced mock progression"
                )
            )
        }

        let userCategory = UserCategory(
            name: "Hybrid Conditioning",
            iconName: "bolt.heart.fill",
            colorHex: "34C759",
            defaultInputType: .durationIntensity,
            sortOrder: 0
        )
        context.insert(userCategory)

        let customExercise = CustomExercise(
            name: "Simulator Sled Push",
            category: .cardio,
            inputType: .durationIntensity,
            primaryMuscles: [.quadriceps, .glutes],
            secondaryMuscles: [.core],
            equipment: .machine,
            metValue: 8.6,
            customCategoryName: userCategory.name,
            cardioSecondaryUnit: .meters
        )
        context.insert(customExercise)

        context.insert(
            WorkoutTemplate(
                name: "Advanced Athlete Strength",
                exerciseEntries: [
                    TemplateEntry(
                        exerciseDefinitionID: "barbell-back-squat",
                        exerciseName: "Back Squat",
                        defaultSets: 4,
                        defaultReps: 5,
                        defaultWeightKg: 120,
                        restDuration: 120,
                        equipment: Equipment.barbell.rawValue,
                        inputTypeRaw: ExerciseInputType.setsRepsWeight.rawValue
                    ),
                    TemplateEntry(
                        exerciseDefinitionID: "barbell-bench-press",
                        exerciseName: "Bench Press",
                        defaultSets: 4,
                        defaultReps: 6,
                        defaultWeightKg: 85,
                        restDuration: 90,
                        equipment: Equipment.barbell.rawValue,
                        inputTypeRaw: ExerciseInputType.setsRepsWeight.rawValue
                    )
                ]
            )
        )

        context.insert(
            WorkoutTemplate(
                name: "Aerobic Builder",
                exerciseEntries: [
                    TemplateEntry(
                        exerciseDefinitionID: "running",
                        exerciseName: "Tempo Run",
                        defaultSets: 1,
                        defaultReps: 1,
                        defaultWeightKg: nil,
                        restDuration: nil,
                        equipment: nil,
                        inputTypeRaw: ExerciseInputType.durationDistance.rawValue,
                        cardioSecondaryUnitRaw: CardioSecondaryUnit.km.rawValue
                    ),
                    TemplateEntry(
                        exerciseDefinitionID: "stair-stepper",
                        exerciseName: "Stair Stepper",
                        defaultSets: 1,
                        defaultReps: 1,
                        defaultWeightKg: nil,
                        restDuration: nil,
                        equipment: Equipment.machine.rawValue,
                        inputTypeRaw: ExerciseInputType.durationIntensity.rawValue,
                        cardioSecondaryUnitRaw: CardioSecondaryUnit.floors.rawValue
                    )
                ]
            )
        )

        for record in buildExerciseRecords(from: dataSet.workouts) {
            context.insert(record)
        }
#endif
    }

    @MainActor
    private static func deleteAll<Model: PersistentModel>(
        _ model: Model.Type,
        from context: ModelContext
    ) throws {
        let records = try context.fetch(FetchDescriptor<Model>())
        for record in records {
            context.delete(record)
        }
    }

#if os(iOS)
    private static func buildExerciseRecords(
        from workouts: [SimulatorAdvancedMockWorkout]
    ) -> [ExerciseRecord] {
        let strengthDates = workouts
            .filter {
                $0.summary.activityType == .traditionalStrengthTraining
                    || $0.summary.activityType == .functionalStrengthTraining
            }
            .map(\.summary.date)

        var records: [ExerciseRecord] = []

        if let upperDate = strengthDates.first {
            let bench = ExerciseRecord(
                date: upperDate,
                exerciseType: "strength",
                duration: 52 * 60,
                calories: 286,
                isFromHealthKit: false,
                exerciseDefinitionID: "barbell-bench-press",
                primaryMuscles: [.chest],
                secondaryMuscles: [.triceps, .shoulders],
                equipment: .barbell,
                estimatedCalories: 286,
                calorieSource: .met,
                rpe: 9
            )
            bench.sets = [
                completedSet(1, weight: 80, reps: 8, rest: 90, for: bench),
                completedSet(2, weight: 82.5, reps: 8, rest: 90, for: bench),
                completedSet(3, weight: 85, reps: 6, rest: 120, for: bench),
            ]
            records.append(bench)

            let pullUps = ExerciseRecord(
                date: upperDate.addingTimeInterval(16 * 60),
                exerciseType: "strength",
                duration: 24 * 60,
                calories: 112,
                isFromHealthKit: false,
                exerciseDefinitionID: "pull-up",
                primaryMuscles: [.lats],
                secondaryMuscles: [.biceps, .forearms],
                equipment: .bodyweight,
                estimatedCalories: 112,
                calorieSource: .met,
                rpe: 8
            )
            pullUps.sets = [
                completedSet(1, weight: nil, reps: 10, rest: 75, for: pullUps),
                completedSet(2, weight: nil, reps: 9, rest: 75, for: pullUps),
                completedSet(3, weight: nil, reps: 8, rest: 90, for: pullUps),
            ]
            records.append(pullUps)
        }

        if let lowerDate = strengthDates.dropFirst().first {
            let squat = ExerciseRecord(
                date: lowerDate,
                exerciseType: "strength",
                duration: 54 * 60,
                calories: 322,
                isFromHealthKit: false,
                exerciseDefinitionID: "barbell-back-squat",
                primaryMuscles: [.quadriceps, .glutes],
                secondaryMuscles: [.hamstrings, .core],
                equipment: .barbell,
                estimatedCalories: 322,
                calorieSource: .met,
                rpe: 9
            )
            squat.sets = [
                completedSet(1, weight: 120, reps: 5, rest: 120, for: squat),
                completedSet(2, weight: 125, reps: 5, rest: 120, for: squat),
                completedSet(3, weight: 130, reps: 4, rest: 150, for: squat),
            ]
            records.append(squat)

            let deadlift = ExerciseRecord(
                date: lowerDate.addingTimeInterval(18 * 60),
                exerciseType: "strength",
                duration: 28 * 60,
                calories: 198,
                isFromHealthKit: false,
                exerciseDefinitionID: "conventional-deadlift",
                primaryMuscles: [.hamstrings, .glutes, .back],
                secondaryMuscles: [.core, .forearms],
                equipment: .barbell,
                estimatedCalories: 198,
                calorieSource: .met,
                rpe: 8
            )
            deadlift.sets = [
                completedSet(1, weight: 150, reps: 5, rest: 150, for: deadlift),
                completedSet(2, weight: 160, reps: 4, rest: 180, for: deadlift),
                completedSet(3, weight: 165, reps: 3, rest: 180, for: deadlift),
            ]
            records.append(deadlift)
        }

        for workout in workouts where workout.summary.activityType.isDistanceBased || workout.summary.activityType.isStairBased {
            let summary = workout.summary
            records.append(
                ExerciseRecord(
                    date: summary.date,
                    exerciseType: summary.activityType.rawValue,
                    duration: summary.duration,
                    calories: summary.calories,
                    distance: summary.distance,
                    stepCount: summary.stepCount.flatMap { Int($0.rounded()) },
                    averagePaceSecondsPerKm: summary.averagePace,
                    elevationGainMeters: summary.elevationAscended,
                    floorsAscended: summary.flightsClimbed,
                    memo: summary.type,
                    isFromHealthKit: true,
                    healthKitWorkoutID: summary.id,
                    exerciseDefinitionID: nil,
                    primaryMuscles: summary.activityType.primaryMuscles,
                    secondaryMuscles: summary.activityType.secondaryMuscles,
                    equipment: summary.isIndoor == true ? .machine : .none,
                    estimatedCalories: summary.calories,
                    calorieSource: .healthKit,
                    rpe: summary.effortScore.flatMap { Int($0.rounded()) },
                    cardioFitnessVO2Max: summary.activityType == .running ? 48.6 : nil
                )
            )
        }

        return records.sorted { $0.date > $1.date }
    }

    private static func completedSet(
        _ setNumber: Int,
        weight: Double?,
        reps: Int?,
        rest: TimeInterval,
        for record: ExerciseRecord
    ) -> WorkoutSet {
        let set = WorkoutSet(
            setNumber: setNumber,
            weight: weight,
            reps: reps,
            isCompleted: true,
            restDuration: rest
        )
        set.exerciseRecord = record
        return set
    }
#endif
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
