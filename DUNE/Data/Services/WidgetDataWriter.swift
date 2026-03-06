import Foundation
import WidgetKit

/// Writes score data to App Group UserDefaults for the widget extension to read.
/// Each ViewModel updates its own score fields, preserving the others.
/// All callers are @MainActor, so read-modify-write is serialized.
@MainActor
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
        do {
            return try decoder.decode(WidgetScoreData.self, from: jsonData)
        } catch {
            AppLogger.data.error("[WidgetDataWriter] Corrupt widget blob, removing: \(error)")
            defaults?.removeObject(forKey: WidgetScoreData.userDefaultsKey)
            return nil
        }
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

    private static func update(_ mutation: (inout WidgetScoreData) -> Void) {
        var data = loadExisting() ?? WidgetScoreData(
            conditionScore: nil, conditionStatusRaw: nil, conditionMessage: nil,
            readinessScore: nil, readinessStatusRaw: nil, readinessMessage: nil,
            wellnessScore: nil, wellnessStatusRaw: nil, wellnessMessage: nil,
            updatedAt: Date()
        )
        mutation(&data)
        data.updatedAt = Date()
        save(data)
    }

    static func writeConditionScore(_ score: ConditionScore?) {
        update { data in
            data.conditionScore = score?.score
            data.conditionStatusRaw = score?.status.rawValue
            data.conditionMessage = score?.narrativeMessage
        }
    }

    static func writeReadinessScore(_ score: TrainingReadiness?) {
        update { data in
            data.readinessScore = score?.score
            data.readinessStatusRaw = score?.status.rawValue
            data.readinessMessage = score?.narrativeMessage
        }
    }

    static func writeWellnessScore(_ score: WellnessScore?) {
        update { data in
            data.wellnessScore = score?.score
            data.wellnessStatusRaw = score?.status.rawValue
            data.wellnessMessage = score?.narrativeMessage
        }
    }
}
