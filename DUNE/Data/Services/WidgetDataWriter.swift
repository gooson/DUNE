import Foundation
import WidgetKit

/// Writes score data to App Group UserDefaults for the widget extension to read.
/// Each ViewModel updates its own score fields, preserving the others.
enum WidgetDataWriter {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    private static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: WidgetScoreData.appGroupID)
    }

    private static func loadExisting(from defaults: UserDefaults) -> WidgetScoreData? {
        guard let jsonData = defaults.data(forKey: WidgetScoreData.userDefaultsKey) else { return nil }
        return try? decoder.decode(WidgetScoreData.self, from: jsonData)
    }

    private static func save(_ data: WidgetScoreData, to defaults: UserDefaults) {
        do {
            let jsonData = try encoder.encode(data)
            defaults.set(jsonData, forKey: WidgetScoreData.userDefaultsKey)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            AppLogger.data.error("[WidgetDataWriter] Failed to encode widget data: \(error)")
        }
    }

    static func writeConditionScore(_ score: ConditionScore?) {
        guard let defaults = sharedDefaults() else { return }
        let existing = loadExisting(from: defaults)
        let updated = WidgetScoreData(
            conditionScore: score?.score,
            conditionStatusRaw: score?.status.rawValue,
            conditionMessage: score?.narrativeMessage,
            readinessScore: existing?.readinessScore,
            readinessStatusRaw: existing?.readinessStatusRaw,
            readinessMessage: existing?.readinessMessage,
            wellnessScore: existing?.wellnessScore,
            wellnessStatusRaw: existing?.wellnessStatusRaw,
            wellnessMessage: existing?.wellnessMessage,
            updatedAt: Date()
        )
        save(updated, to: defaults)
    }

    static func writeReadinessScore(_ score: TrainingReadiness?) {
        guard let defaults = sharedDefaults() else { return }
        let existing = loadExisting(from: defaults)
        let updated = WidgetScoreData(
            conditionScore: existing?.conditionScore,
            conditionStatusRaw: existing?.conditionStatusRaw,
            conditionMessage: existing?.conditionMessage,
            readinessScore: score?.score,
            readinessStatusRaw: score?.status.rawValue,
            readinessMessage: score?.narrativeMessage,
            wellnessScore: existing?.wellnessScore,
            wellnessStatusRaw: existing?.wellnessStatusRaw,
            wellnessMessage: existing?.wellnessMessage,
            updatedAt: Date()
        )
        save(updated, to: defaults)
    }

    static func writeWellnessScore(_ score: WellnessScore?) {
        guard let defaults = sharedDefaults() else { return }
        let existing = loadExisting(from: defaults)
        let updated = WidgetScoreData(
            conditionScore: existing?.conditionScore,
            conditionStatusRaw: existing?.conditionStatusRaw,
            conditionMessage: existing?.conditionMessage,
            readinessScore: existing?.readinessScore,
            readinessStatusRaw: existing?.readinessStatusRaw,
            readinessMessage: existing?.readinessMessage,
            wellnessScore: score?.score,
            wellnessStatusRaw: score?.status.rawValue,
            wellnessMessage: score?.narrativeMessage,
            updatedAt: Date()
        )
        save(updated, to: defaults)
    }
}
