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
    /// Rolling 24h window duration in seconds. Shared by sparklines, detail views, and chart helpers.
    static let rollingWindowSeconds: TimeInterval = 24 * 60 * 60

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
            // Only mutate fields that actually changed to avoid unnecessary
            // CloudKit sync (dirty record → sync → remote change notification → loop).
            var changed = false
            if let v = clampedCondition, existing.conditionScore != v {
                existing.conditionScore = v; changed = true
            }
            if let v = clampedWellness, existing.wellnessScore != v {
                existing.wellnessScore = v; changed = true
            }
            if let v = clampedReadiness, existing.readinessScore != v {
                existing.readinessScore = v; changed = true
            }
            if let v = clampedHRV, existing.hrvValue != v {
                existing.hrvValue = v; changed = true
            }
            if let v = clampedRHR, existing.rhrValue != v {
                existing.rhrValue = v; changed = true
            }
            if let v = clampedSleep, existing.sleepScore != v {
                existing.sleepScore = v; changed = true
            }
            guard changed else {
                lastRefreshedAt = now
                scheduleSparklineReload()
                return
            }
            existing.createdAt = now
        } else {
            // All fields nil means nothing to record — skip insert entirely.
            guard clampedCondition != nil || clampedWellness != nil || clampedReadiness != nil
                    || clampedHRV != nil || clampedRHR != nil || clampedSleep != nil else {
                return
            }
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
        let twentyFourHoursAgo = now.addingTimeInterval(-Self.rollingWindowSeconds)

        guard let snapshots = try? context.fetch(rolling24hDescriptor(from: twentyFourHoursAgo)),
              !snapshots.isEmpty else {
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

    /// Fetch hourly snapshots for the rolling 24h window (now - 24h to now).
    /// Used by wellness/readiness detail views for day-period hourly charts.
    func fetchRolling24hSnapshots() async -> [HourlyScoreSnapshot] {
        await fetchRollingSnapshots(hoursBack: 24)
    }

    /// Fetch hourly snapshots for a rolling time window (now - hoursBack to now).
    func fetchRollingSnapshots(hoursBack: Int) async -> [HourlyScoreSnapshot] {
        let clampedHours = max(1, hoursBack)
        let startDate = Date().addingTimeInterval(-TimeInterval(clampedHours) * 60 * 60)
        let fetchLimit = max(48, clampedHours * 2)
        return (try? context.fetch(rollingDescriptor(from: startDate, fetchLimit: fetchLimit))) ?? []
    }

    // MARK: - Private

    private func rollingDescriptor(from startDate: Date, fetchLimit: Int) -> FetchDescriptor<HourlyScoreSnapshot> {
        var descriptor = FetchDescriptor<HourlyScoreSnapshot>(
            predicate: #Predicate { $0.date >= startDate },
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.fetchLimit = max(1, fetchLimit)
        return descriptor
    }

    private func rolling24hDescriptor(from startDate: Date) -> FetchDescriptor<HourlyScoreSnapshot> {
        rollingDescriptor(from: startDate, fetchLimit: 48)
    }

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
