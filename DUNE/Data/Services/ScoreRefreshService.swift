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

    private let context: ModelContext

    // MARK: - Internal State

    private var listenTask: Task<Void, Never>?
    private var sparklineReloadTask: Task<Void, Never>?

    // MARK: - Init

    init(modelContainer: ModelContainer) {
        self.context = ModelContext(modelContainer)
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
    /// Multiple callers may invoke this with partial data (e.g. only conditionScore);
    /// the upsert merges non-nil fields into the existing row.
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

        // Clamp score values to valid 0-100 range before persisting
        let clampedCondition = conditionScore.map { Double(min(max($0, 0), 100)) }
        let clampedWellness = wellnessScore.map { Double(min(max($0, 0), 100)) }
        let clampedReadiness = readinessScore.map { Double(min(max($0, 0), 100)) }
        let clampedHRV = hrvValue.flatMap { $0.isFinite && $0 >= 0 && $0 <= 500 ? $0 : nil }
        let clampedRHR = rhrValue.flatMap { $0.isFinite && $0 >= 20 && $0 <= 300 ? $0 : nil }
        let clampedSleep = sleepScore.flatMap { $0.isFinite && $0 >= 0 && $0 <= 100 ? $0 : nil }

        // Upsert: range predicate spanning the full hour (DST/rounding safe)
        let calendar = Calendar.current
        let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourDate) ?? hourDate
        var descriptor = FetchDescriptor<HourlyScoreSnapshot>(
            predicate: #Predicate { $0.date >= hourDate && $0.date < hourEnd }
        )
        descriptor.fetchLimit = 1

        let existing = try? context.fetch(descriptor).first

        if let existing {
            if let v = clampedCondition { existing.conditionScore = v }
            if let v = clampedWellness { existing.wellnessScore = v }
            if let v = clampedReadiness { existing.readinessScore = v }
            if let v = clampedHRV { existing.hrvValue = v }
            if let v = clampedRHR { existing.rhrValue = v }
            if let v = clampedSleep { existing.sleepScore = v }
            existing.createdAt = now
        } else {
            let snap = HourlyScoreSnapshot(
                date: hourDate,
                conditionScore: clampedCondition,
                wellnessScore: clampedWellness,
                readinessScore: clampedReadiness,
                hrvValue: clampedHRV,
                rhrValue: clampedRHR,
                sleepScore: clampedSleep
            )
            context.insert(snap)
        }

        do {
            try context.save()
            AppLogger.data.info("[ScoreRefreshService] Saved hourly snapshot at \(hourDate)")
        } catch {
            AppLogger.data.error("[ScoreRefreshService] Failed to save hourly snapshot: \(error.localizedDescription)")
        }

        lastRefreshedAt = now
        scheduleSparklineReload()
    }

    /// Debounced sparkline reload — coalesces multiple rapid recordSnapshot calls
    /// (from Dashboard, Wellness, Activity VMs) into a single fetch.
    private func scheduleSparklineReload() {
        sparklineReloadTask?.cancel()
        sparklineReloadTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            await loadTodaySparklines()
        }
    }

    /// Load rolling 24-hour sparkline data from persisted snapshots.
    /// At the start of a new day, yesterday's data provides continuity.
    func loadTodaySparklines() async {
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let twentyFourHoursAgo = now.addingTimeInterval(-24 * 60 * 60)

        var descriptor = FetchDescriptor<HourlyScoreSnapshot>(
            predicate: #Predicate { $0.date >= twentyFourHoursAgo },
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.fetchLimit = 48 // max 24h of hourly snapshots with some margin

        guard let snapshots = try? context.fetch(descriptor), !snapshots.isEmpty else {
            conditionSparkline = .empty
            wellnessSparkline = .empty
            readinessSparkline = .empty
            return
        }

        let hasYesterday = snapshots.first.map { $0.date < startOfDay } ?? false

        conditionSparkline = buildSparkline(from: snapshots, keyPath: \.conditionScore, includesYesterday: hasYesterday)
        wellnessSparkline = buildSparkline(from: snapshots, keyPath: \.wellnessScore, includesYesterday: hasYesterday)
        readinessSparkline = buildSparkline(from: snapshots, keyPath: \.readinessScore, includesYesterday: hasYesterday)
    }

    /// Fetch hourly snapshots for a specific date (for detail view drill-down).
    func fetchSnapshots(for date: Date) async -> [HourlyScoreSnapshot] {
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
        keyPath: KeyPath<HourlyScoreSnapshot, Double?>,
        includesYesterday: Bool
    ) -> HourlySparklineData {
        let calendar = Calendar.current
        let raw: [(hour: Int, score: Double)] = snapshots.compactMap { snap in
            guard let score = snap[keyPath: keyPath] else { return nil }
            let hour = calendar.component(.hour, from: snap.date)
            return (hour: hour, score: score)
        }
        let indexed: [HourlySparklineData.HourlyPoint] = raw.enumerated().map { idx, pair in
            HourlySparklineData.HourlyPoint(index: idx, hour: pair.hour, score: pair.score)
        }

        guard let last = indexed.last else { return .empty }
        let previous = indexed.count >= 2 ? indexed[indexed.count - 2].score : nil

        return HourlySparklineData(
            points: indexed,
            currentScore: last.score,
            previousScore: previous,
            includesYesterday: includesYesterday
        )
    }
}
