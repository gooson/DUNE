import Foundation

enum WorkoutLiveActivityMetric: String, CaseIterable, Codable, Sendable {
    case elapsedTime
    case distance
    case heartRate
    case weight

    var displayName: String {
        switch self {
        case .elapsedTime: String(localized: "Elapsed Time")
        case .distance: String(localized: "Distance")
        case .heartRate: String(localized: "Heart Rate")
        case .weight: String(localized: "Current Set Weight")
        }
    }
}

enum WorkoutLiveActivityStyle: String, CaseIterable, Codable, Sendable {
    case standard
    case goldImpact

    var displayName: String {
        switch self {
        case .standard: String(localized: "Standard")
        case .goldImpact: String(localized: "Gold Impact")
        }
    }
}

struct WorkoutLiveActivityPreferences: Codable, Hashable, Sendable {
    static let cardioMetricKey = "workoutLiveActivity.cardioMetric"
    static let strengthMetricKey = "workoutLiveActivity.strengthMetric"
    static let styleKey = "workoutLiveActivity.style"

    var cardioMetric: WorkoutLiveActivityMetric = .elapsedTime
    var strengthMetric: WorkoutLiveActivityMetric = .elapsedTime
    var style: WorkoutLiveActivityStyle = .goldImpact

    static func read(defaults: UserDefaults? = WidgetScoreData.sharedDefaults() ?? .standard) -> Self {
        let defaults = defaults ?? .standard
        var preferences = Self()
        if let raw = defaults.string(forKey: cardioMetricKey),
           let metric = WorkoutLiveActivityMetric(rawValue: raw),
           [.elapsedTime, .distance, .heartRate].contains(metric) {
            preferences.cardioMetric = metric
        }
        if let raw = defaults.string(forKey: strengthMetricKey),
           let metric = WorkoutLiveActivityMetric(rawValue: raw),
           [.elapsedTime, .weight, .heartRate].contains(metric) {
            preferences.strengthMetric = metric
        }
        if let raw = defaults.string(forKey: styleKey),
           let style = WorkoutLiveActivityStyle(rawValue: raw) {
            preferences.style = style
        }
        return preferences
    }

    func save(to defaults: UserDefaults? = WidgetScoreData.sharedDefaults() ?? .standard) {
        let defaults = defaults ?? .standard
        defaults.set(cardioMetric.rawValue, forKey: Self.cardioMetricKey)
        defaults.set(strengthMetric.rawValue, forKey: Self.strengthMetricKey)
        defaults.set(style.rawValue, forKey: Self.styleKey)
    }

    func resolvedMetric(for snapshot: WatchWorkoutSnapshot) -> WorkoutLiveActivityMetric {
        switch snapshot.workoutKind {
        case .cardio:
            switch cardioMetric {
            case .distance:
                return snapshot.supportsDistance == true && snapshot.distanceMeters.isFinite
                    && (0...1_000_000).contains(snapshot.distanceMeters) ? .distance : .elapsedTime
            case .heartRate:
                return Self.hasValidHeartRate(snapshot.heartRate) ? .heartRate : .elapsedTime
            case .elapsedTime:
                return .elapsedTime
            case .weight:
                return .elapsedTime
            }
        case .strength:
            switch strengthMetric {
            case .weight:
                guard let weight = snapshot.currentSetWeightKg,
                      weight.isFinite, (0...500).contains(weight) else { return .elapsedTime }
                return .weight
            case .heartRate:
                return Self.hasValidHeartRate(snapshot.heartRate) ? .heartRate : .elapsedTime
            case .elapsedTime:
                return .elapsedTime
            case .distance:
                return .elapsedTime
            }
        case nil:
            return .elapsedTime
        }
    }

    private static func hasValidHeartRate(_ value: Double?) -> Bool {
        guard let value else { return false }
        return value.isFinite && (20...250).contains(value)
    }
}
