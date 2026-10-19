import Foundation
import WidgetKit

/// Writes score data to an App Group file for the widget extension to read.
/// Each ViewModel updates its own score fields, preserving the others.
/// All callers are @MainActor, so read-modify-write is serialized.
@MainActor
enum WidgetDataWriter {
    static let themeDefaultsKey = "com.raftel.dailve.app_theme"
    // Debounce reloadAllTimelines to coalesce rapid writes from multiple VMs.
    private static var reloadWorkItem: DispatchWorkItem?

    private static func loadExisting() -> WidgetScoreData? {
        WidgetScoreData.loadSharedData()
    }

    private static func save(_ data: WidgetScoreData) {
        do {
            try WidgetScoreData.saveSharedData(data)
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

    static func writeTheme(_ theme: AppTheme) {
        guard let defaults = WidgetScoreData.sharedDefaults() else { return }
        guard defaults.string(forKey: themeDefaultsKey) != theme.rawValue else { return }
        defaults.set(theme.rawValue, forKey: themeDefaultsKey)
        scheduleReload()
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
