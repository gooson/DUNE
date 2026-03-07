import Foundation
import WidgetKit

struct WidgetScoreProvider: TimelineProvider {
    func placeholder(in context: Context) -> WellnessDashboardEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WellnessDashboardEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(loadCurrentEntry())
        }
    }

    private static let calendar = Calendar.autoupdatingCurrent

    func getTimeline(in context: Context, completion: @escaping (Timeline<WellnessDashboardEntry>) -> Void) {
        let entry = loadCurrentEntry()

        // Refresh at the next hour boundary
        let nextHour = Self.calendar.nextDate(
            after: entry.date,
            matching: DateComponents(minute: 0),
            matchingPolicy: .nextTime
        ) ?? entry.date.addingTimeInterval(3600)

        let timeline = Timeline(entries: [entry], policy: .after(nextHour))
        completion(timeline)
    }

    private func loadCurrentEntry() -> WellnessDashboardEntry {
        guard let data = WidgetScoreData.loadSharedData() else {
            return WellnessDashboardEntry(
                date: .now,
                conditionScore: nil, conditionStatusRaw: nil, conditionMessage: nil,
                readinessScore: nil, readinessStatusRaw: nil, readinessMessage: nil,
                wellnessScore: nil, wellnessStatusRaw: nil, wellnessMessage: nil,
                scoreUpdatedAt: nil
            )
        }

        return WellnessDashboardEntry(
            date: .now,
            conditionScore: data.conditionScore,
            conditionStatusRaw: data.conditionStatusRaw,
            conditionMessage: data.conditionMessage,
            readinessScore: data.readinessScore,
            readinessStatusRaw: data.readinessStatusRaw,
            readinessMessage: data.readinessMessage,
            wellnessScore: data.wellnessScore,
            wellnessStatusRaw: data.wellnessStatusRaw,
            wellnessMessage: data.wellnessMessage,
            scoreUpdatedAt: data.updatedAt
        )
    }
}
