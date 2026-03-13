import Foundation
import Observation
import SwiftData
import OSLog

/// Service that persists hourly score snapshots and exposes live sparkline data
/// for hero cards across all tabs.
///
/// Hooks into `AppRefreshCoordinating.refreshNeededStream` to capture scores
/// when HealthKit data changes, and persists hourly snapshots to SwiftData.
@Observable
@MainActor
final class ScoreRefreshService {
    // MARK: - Published State

    private(set) var conditionSparkline: HourlySparklineData = .empty
    private(set) var wellnessSparkline: HourlySparklineData = .empty
    private(set) var readinessSparkline: HourlySparklineData = .empty

    private(set) var lastRefreshedAt: Date?

    // MARK: - Dependencies

    private let modelContainer: ModelContainer

    // MARK: - Internal State

    private var listenTask: Task<Void, Never>?
    private var lastSnapshotHour: Date?

    // MARK: - Init

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Public API

    /// Start listening to refresh stream. Call once at app launch.
    func startListening(to coordinator: AppRefreshCoordinating) {
        listenTask?.cancel()
        listenTask = Task { [weak self] in
            for await _ in coordinator.refreshNeededStream {
                guard !Task.isCancelled else { return }
                await self?.loadTodaySparklines()
            }
        }
    }

    /// Record a score snapshot for the current hour.
    /// Called by ViewModels after they compute scores from SharedHealthSnapshot.
    func recordSnapshot(
        conditionScore: Int?,
        wellnessScore: Int?,
        readinessScore: Int?,
        hrvValue: Double? = nil,
        rhrValue: Double? = nil,
        sleepScore: Double? = nil
    ) async {
        let now = Date()
        let hourDate = HourlyScoreSnapshot.hourTruncated(now)

        // Skip if we already saved a snapshot for this hour
        if let lastHour = lastSnapshotHour, lastHour == hourDate { return }

        let context = ModelContext(modelContainer)

        // Upsert: check for existing snapshot at this hour
        var descriptor = FetchDescriptor<HourlyScoreSnapshot>(
            predicate: #Predicate { $0.date == hourDate }
        )
        descriptor.fetchLimit = 1

        let existing = try? context.fetch(descriptor).first

        if let existing {
            if let v = conditionScore { existing.conditionScore = Double(v) }
            if let v = wellnessScore { existing.wellnessScore = Double(v) }
            if let v = readinessScore { existing.readinessScore = Double(v) }
            if let v = hrvValue { existing.hrvValue = v }
            if let v = rhrValue { existing.rhrValue = v }
            if let v = sleepScore { existing.sleepScore = v }
            existing.createdAt = now
        } else {
            let snap = HourlyScoreSnapshot(
                date: hourDate,
                conditionScore: conditionScore.map { Double($0) },
                wellnessScore: wellnessScore.map { Double($0) },
                readinessScore: readinessScore.map { Double($0) },
                hrvValue: hrvValue,
                rhrValue: rhrValue,
                sleepScore: sleepScore
            )
            context.insert(snap)
        }

        do {
            try context.save()
            lastSnapshotHour = hourDate
            AppLogger.data.info("[ScoreRefreshService] Saved hourly snapshot at \(hourDate)")
        } catch {
            AppLogger.data.error("[ScoreRefreshService] Failed to save hourly snapshot: \(error.localizedDescription)")
        }

        // Refresh sparklines after saving
        await loadTodaySparklines()
        lastRefreshedAt = now
    }

    /// Load today's sparkline data from persisted snapshots.
    func loadTodaySparklines() async {
        let context = ModelContext(modelContainer)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        var descriptor = FetchDescriptor<HourlyScoreSnapshot>(
            predicate: #Predicate { $0.date >= startOfDay },
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.fetchLimit = 24

        guard let snapshots = try? context.fetch(descriptor), !snapshots.isEmpty else { return }

        conditionSparkline = buildSparkline(from: snapshots, keyPath: \.conditionScore)
        wellnessSparkline = buildSparkline(from: snapshots, keyPath: \.wellnessScore)
        readinessSparkline = buildSparkline(from: snapshots, keyPath: \.readinessScore)
    }

    /// Fetch hourly snapshots for a specific date (for detail view drill-down).
    func fetchSnapshots(for date: Date) async -> [HourlyScoreSnapshot] {
        let context = ModelContext(modelContainer)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        var descriptor = FetchDescriptor<HourlyScoreSnapshot>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay },
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.fetchLimit = 24

        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Private

    private func buildSparkline(
        from snapshots: [HourlyScoreSnapshot],
        keyPath: KeyPath<HourlyScoreSnapshot, Double?>
    ) -> HourlySparklineData {
        let calendar = Calendar.current
        let points: [HourlySparklineData.HourlyPoint] = snapshots.compactMap { snap in
            guard let score = snap[keyPath: keyPath] else { return nil }
            let hour = calendar.component(.hour, from: snap.date)
            return HourlySparklineData.HourlyPoint(hour: hour, score: score)
        }

        guard let last = points.last else { return .empty }
        let previous = points.count >= 2 ? points[points.count - 2].score : nil

        return HourlySparklineData(
            points: points,
            currentScore: last.score,
            previousScore: previous
        )
    }
}
