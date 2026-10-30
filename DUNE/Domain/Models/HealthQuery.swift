import Foundation

enum HealthQueryKind: String, CaseIterable, Codable, Sendable {
    case latestWorkout, workoutSummary, strengthSets, personalRecord
    case cardioDetail, latestBody, bodyTrend, sleep, condition
    case metricComparison, workoutComparison, memoSearch, report, longAnalysis
}

enum HealthQueryPeriod: String, CaseIterable, Codable, Sendable {
    case today, yesterday, thisWeek, lastWeek, thisMonth, lastMonth
    case last7Days, last30Days, last90Days, last365Days

    func interval(endingAt now: Date, calendar: Calendar = .current) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        let end = max(now, today.addingTimeInterval(0.001))
        func preceding(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: today) ?? today
        }
        switch self {
        case .today: return DateInterval(start: today, end: end)
        case .yesterday: return DateInterval(start: preceding(1), end: today)
        case .thisWeek:
            return DateInterval(start: calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today, end: end)
        case .lastWeek:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
            return DateInterval(start: calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart, end: weekStart)
        case .thisMonth:
            return DateInterval(start: calendar.dateInterval(of: .month, for: now)?.start ?? today, end: end)
        case .lastMonth:
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? today
            return DateInterval(start: calendar.date(byAdding: .month, value: -1, to: monthStart) ?? monthStart, end: monthStart)
        case .last7Days: return DateInterval(start: preceding(6), end: end)
        case .last30Days: return DateInterval(start: preceding(29), end: end)
        case .last90Days: return DateInterval(start: preceding(89), end: end)
        case .last365Days: return DateInterval(start: preceding(364), end: end)
        }
    }
}

struct HealthQueryRequest: Sendable, Equatable {
    var kind: HealthQueryKind
    var interval: DateInterval?
    var comparisonInterval: DateInterval?
    var workoutID: String?
    var workoutIDs: [String]
    var exerciseID: String?
    var searchText: String?
    var limit: Int

    init(
        kind: HealthQueryKind,
        interval: DateInterval? = nil,
        comparisonInterval: DateInterval? = nil,
        workoutID: String? = nil,
        exerciseID: String? = nil,
        searchText: String? = nil,
        limit: Int = 20,
        workoutIDs: [String] = []
    ) {
        self.kind = kind
        self.interval = interval
        self.comparisonInterval = comparisonInterval
        self.workoutID = workoutID
        self.workoutIDs = Array(workoutIDs.prefix(40))
        self.exerciseID = exerciseID
        self.searchText = searchText
        self.limit = limit
    }
}

enum HealthQueryStatus: String, Codable, Sendable {
    case available, partial, noData, locked, unavailable, invalidRequest
}

enum HealthQueryExplanationStatus: String, Codable, Sendable {
    case notRequested, generated, unavailable, offline, quotaReached
}

enum HealthQueryUnit: String, Codable, Sendable {
    case count, seconds, meters, kilograms, kilocalories, percent, bpm, milliseconds, score
    case kilogramRepetitions, secondsPerKilometer, bodyMassIndex
}

struct HealthQueryMetric: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let value: Double
    let unit: HealthQueryUnit
    var date: Date?
    var comparisonValue: Double?
    var comparisonDate: Date?

    init(id: String, title: String, value: Double, unit: HealthQueryUnit, date: Date? = nil,
         comparisonValue: Double? = nil, comparisonDate: Date? = nil) {
        self.id = id
        self.title = title
        self.value = value
        self.unit = unit
        self.date = date
        self.comparisonValue = comparisonValue
        self.comparisonDate = comparisonDate
    }
}

struct HealthQueryPoint: Identifiable, Sendable, Equatable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct HealthQuerySeries: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let unit: HealthQueryUnit
    let points: [HealthQueryPoint]
}

struct HealthQuerySource: Sendable, Equatable {
    enum Kind: String, Codable, Sendable { case app, healthKit, calculated }
    let kind: Kind
    var recordID: String?
    var measuredAt: Date?
    let fetchedAt: Date

    init(kind: Kind, recordID: String? = nil, measuredAt: Date? = nil, fetchedAt: Date) {
        self.kind = kind
        self.recordID = recordID
        self.measuredAt = measuredAt
        self.fetchedAt = fetchedAt
    }
}

struct HealthQuerySetSnapshot: Identifiable, Sendable, Equatable {
    let id: String
    let number: Int
    var weightKilograms: Double?
    var reps: Int?
    var durationSeconds: Double?
    var distanceMeters: Double?

    init(id: String, number: Int, weightKilograms: Double? = nil, reps: Int? = nil,
         durationSeconds: Double? = nil, distanceMeters: Double? = nil) {
        self.id = id
        self.number = number
        self.weightKilograms = weightKilograms
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
    }

    var volumeKilogramRepetitions: Double? {
        guard let weightKilograms, weightKilograms.isFinite, weightKilograms > 0,
              weightKilograms <= 500, let reps, (1...100).contains(reps) else { return nil }
        return weightKilograms * Double(reps)
    }
}

struct HealthQueryWorkoutSnapshot: Identifiable, Sendable, Equatable {
    let id: String
    var localRecordID: UUID?
    var healthKitWorkoutID: String?
    var exerciseID: String?
    let name: String
    var activityType: WorkoutActivityType?
    let date: Date
    var durationSeconds: Double?
    var distanceMeters: Double?
    var averagePaceSecondsPerKm: Double?
    var averageHeartRate: Double?
    var calories: Double?
    var completedSets: [HealthQuerySetSnapshot]
    var memo: String
    let source: HealthQuerySource.Kind
    var isFromThisApp: Bool
    /// Present only when HealthKit supplied at least one otherwise absent measurement.
    var supplementalHealthKitSource: HealthQuerySource?

    init(id: String, localRecordID: UUID? = nil, healthKitWorkoutID: String? = nil,
         exerciseID: String? = nil, name: String, activityType: WorkoutActivityType? = nil,
         date: Date, durationSeconds: Double? = nil, distanceMeters: Double? = nil,
         averagePaceSecondsPerKm: Double? = nil, averageHeartRate: Double? = nil,
         calories: Double? = nil, completedSets: [HealthQuerySetSnapshot] = [],
         memo: String = "", source: HealthQuerySource.Kind = .app, isFromThisApp: Bool = false,
         supplementalHealthKitSource: HealthQuerySource? = nil) {
        self.id = id
        self.localRecordID = localRecordID
        self.healthKitWorkoutID = healthKitWorkoutID
        self.exerciseID = exerciseID
        self.name = name
        self.activityType = activityType
        self.date = date
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.averagePaceSecondsPerKm = averagePaceSecondsPerKm
        self.averageHeartRate = averageHeartRate
        self.calories = calories
        self.completedSets = completedSets
        self.memo = memo
        self.source = source
        self.isFromThisApp = isFromThisApp
        self.supplementalHealthKitSource = supplementalHealthKitSource
    }

    var volumeKilogramRepetitions: Double? {
        let volumes = completedSets.compactMap(\.volumeKilogramRepetitions)
        guard !volumes.isEmpty else { return nil }
        let sum = volumes.reduce(0, +)
        return sum.isFinite ? sum : nil
    }
}

struct HealthQueryResult: Sendable, Equatable {
    let kind: HealthQueryKind
    let status: HealthQueryStatus
    let title: String
    let generatedAt: Date
    let interval: DateInterval
    var metrics: [HealthQueryMetric]
    var series: [HealthQuerySeries]
    var records: [HealthQueryWorkoutSnapshot]
    var sources: [HealthQuerySource]
    var spokenSummary: String
    var explanation: String?
    var explanationStatus: HealthQueryExplanationStatus
    var limitations: [String]
    var isComplete: Bool

    init(kind: HealthQueryKind, status: HealthQueryStatus, title: String, generatedAt: Date,
         interval: DateInterval, metrics: [HealthQueryMetric] = [], series: [HealthQuerySeries] = [],
         records: [HealthQueryWorkoutSnapshot] = [], sources: [HealthQuerySource] = [],
         spokenSummary: String, explanation: String? = nil,
         explanationStatus: HealthQueryExplanationStatus = .notRequested,
         limitations: [String] = [], isComplete: Bool = true) {
        self.kind = kind
        self.status = status
        self.title = title
        self.generatedAt = generatedAt
        self.interval = interval
        self.metrics = metrics
        self.series = series
        self.records = records
        self.sources = sources
        self.spokenSummary = spokenSummary
        self.explanation = explanation
        self.explanationStatus = explanationStatus
        self.limitations = limitations
        self.isComplete = isComplete
    }
}
