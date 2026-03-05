import Foundation
import WidgetKit

/// Writes score data to App Group UserDefaults for the widget extension to read.
/// Each ViewModel updates its own score fields, preserving the others.
/// All callers are @MainActor, so read-modify-write is serialized.
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

    private static let defaults = UserDefaults(suiteName: WidgetScoreData.appGroupID)

    // Debounce reloadAllTimelines to coalesce rapid writes from multiple VMs.
    private static var reloadWorkItem: DispatchWorkItem?

    private static func loadExisting() -> WidgetScoreData? {
        guard let jsonData = defaults?.data(forKey: WidgetScoreData.userDefaultsKey) else { return nil }
        return try? decoder.decode(WidgetScoreData.self, from: jsonData)
    }

    private static func save(_ data: WidgetScoreData) {
        guard let defaults else { return }
        do {
            let jsonData = try encoder.encode(data)
            defaults.set(jsonData, forKey: WidgetScoreData.userDefaultsKey)
            scheduleReload()
        } catch {
            AppLogger.data.error("[WidgetDataWriter] Failed to encode widget data: \(error)")
        }
    }

    private static func scheduleReload() {
        reloadWorkItem?.cancel()
        let item = DispatchWorkItem { WidgetCenter.shared.reloadAllTimelines() }
        reloadWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    static func writeConditionScore(_ score: ConditionScore?) {
        let existing = loadExisting()
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
        save(updated)
    }

    static func writeReadinessScore(_ score: TrainingReadiness?) {
        let existing = loadExisting()
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
        save(updated)
    }

    static func writeWellnessScore(_ score: WellnessScore?) {
        let existing = loadExisting()
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
        save(updated)
    }
}
