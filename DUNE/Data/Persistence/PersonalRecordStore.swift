import Foundation

/// Persists personal records and reward progression in UserDefaults.
/// Key prefix uses bundle identifier for test/production isolation (correction #76).
final class PersonalRecordStore: @unchecked Sendable {
    static let shared = PersonalRecordStore()

    private let defaults: UserDefaults
    private let recordKeyPrefix: String
    private let rewardStateKey: String

    private static let maxRewardHistoryEntries = 500
    private static let maxProcessedWorkoutEntries = 2_000

    private enum RewardPoints {
        static let milestonePerTier = 40
        static let personalRecordPerType = 60
        static let pointsPerLevel = 200
    }

    private struct RewardState: Codable {
        var milestoneTierByActivity: [String: Int] = [:]
        var unlockedBadges: [String] = []
        var totalPoints: Int = 0
        var level: Int = 1
        var history: [WorkoutRewardEvent] = []
        var processedWorkoutSignatures: [String: String] = [:]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let bundlePrefix = Bundle.main.bundleIdentifier ?? "com.dailve"
        self.recordKeyPrefix = bundlePrefix + ".personalRecords."
        self.rewardStateKey = bundlePrefix + ".workoutRewards.state"
    }

    /// Returns current records for the given activity type.
    func records(for activityType: WorkoutActivityType) -> [PersonalRecordType: PersonalRecord] {
        let key = recordKeyPrefix + activityType.rawValue
        guard let data = defaults.data(forKey: key) else { return [:] }
        do {
            return try JSONDecoder().decode([PersonalRecordType: PersonalRecord].self, from: data)
        } catch {
            // Corrupted data — reset
            defaults.removeObject(forKey: key)
            return [:]
        }
    }

    /// Checks a workout against existing records and updates if any new PRs.
    /// Returns the list of newly achieved PR types.
    @discardableResult
    func updateIfNewRecords(_ workout: WorkoutSummary) -> [PersonalRecordType] {
        let existing = records(for: workout.activityType)
        let newTypes = PersonalRecordService.detectNewRecords(
            workout: workout,
            existingRecords: existing
        )
        guard !newTypes.isEmpty else { return [] }

        let newRecords = PersonalRecordService.buildRecords(from: workout, types: newTypes)
        var updated = existing
        for (type, record) in newRecords {
            updated[type] = record
        }

        saveRecords(updated, for: workout.activityType)
        return newTypes
    }

    /// Returns all records across all activity types.
    func allRecords() -> [WorkoutActivityType: [PersonalRecordType: PersonalRecord]] {
        var result: [WorkoutActivityType: [PersonalRecordType: PersonalRecord]] = [:]
        for activityType in WorkoutActivityType.allCases {
            let records = records(for: activityType)
            if !records.isEmpty {
                result[activityType] = records
            }
        }
        return result
    }

    /// Returns current reward summary (level, points, badges).
    func rewardSummary() -> WorkoutRewardSummary {
        summary(from: loadRewardState())
    }

    /// Returns latest reward history events.
    func rewardHistory(limit: Int = 50) -> [WorkoutRewardEvent] {
        let state = loadRewardState()
        guard limit > 0 else {
            return state.history.sorted { $0.date > $1.date }
        }
        return Array(state.history.sorted { $0.date > $1.date }.prefix(limit))
    }

    /// Evaluates milestone + PR reward outcomes for a workout and persists history/level progression.
    /// Idempotent per workout signature to guard duplicate sync callbacks.
    @discardableResult
    func evaluateReward(
        for workout: WorkoutSummary,
        newPRTypes: [PersonalRecordType]
    ) -> WorkoutRewardOutcome {
        var state = loadRewardState()
        let milestone = workout.activityType.milestoneAchievement(
            distanceMeters: workout.distance,
            stepCount: workout.stepCount,
            durationSeconds: workout.duration
        )
        let signature = rewardSignature(
            activityType: workout.activityType,
            milestone: milestone,
            newPRTypes: newPRTypes
        )

        if state.processedWorkoutSignatures[workout.id] == signature {
            return WorkoutRewardOutcome(
                events: [],
                representativeEvent: nil,
                summary: summary(from: state)
            )
        }

        var newEvents: [WorkoutRewardEvent] = []
        var sessionPoints = 0
        let activityName = workout.activityType.typeName
        let eventDate = workout.date

        if let milestone {
            let activityKey = workout.activityType.rawValue
            let previousTier = state.milestoneTierByActivity[activityKey] ?? 0
            if milestone.tier > previousTier {
                state.milestoneTierByActivity[activityKey] = milestone.tier

                let crossedTierCount = milestone.tier - previousTier
                let milestonePoints = RewardPoints.milestonePerTier * crossedTierCount
                sessionPoints += milestonePoints

                newEvents.append(
                    WorkoutRewardEvent(
                        id: "milestone-\(workout.id)-\(milestone.key)",
                        workoutID: workout.id,
                        activityTypeRawValue: activityKey,
                        date: eventDate,
                        kind: .milestone,
                        title: String(localized: "Milestone Reached"),
                        detail: "\(activityName): \(milestone.thresholdLabel)",
                        pointsAwarded: milestonePoints,
                        levelAfterEvent: nil
                    )
                )

                let badgeKey = "milestone-\(activityKey)-\(milestone.key)"
                if !state.unlockedBadges.contains(badgeKey) {
                    state.unlockedBadges.append(badgeKey)
                    newEvents.append(
                        WorkoutRewardEvent(
                            id: "badge-\(workout.id)-\(badgeKey)",
                            workoutID: workout.id,
                            activityTypeRawValue: activityKey,
                            date: eventDate,
                            kind: .badgeUnlocked,
                            title: String(localized: "New Badge Unlocked"),
                            detail: "\(activityName): \(milestone.thresholdLabel)",
                            pointsAwarded: 0,
                            levelAfterEvent: nil
                        )
                    )
                }
            }
        }

        let uniquePRTypes = Array(Set(newPRTypes)).sorted { $0.rawValue < $1.rawValue }
        if !uniquePRTypes.isEmpty {
            let prPoints = RewardPoints.personalRecordPerType * uniquePRTypes.count
            sessionPoints += prPoints

            let prTypeNames = uniquePRTypes.map { prDisplayName(for: $0) }.joined(separator: ", ")
            let prTypeSignature = uniquePRTypes.map(\.rawValue).joined(separator: "-")

            newEvents.append(
                WorkoutRewardEvent(
                    id: "pr-\(workout.id)-\(prTypeSignature)",
                    workoutID: workout.id,
                    activityTypeRawValue: workout.activityType.rawValue,
                    date: eventDate,
                    kind: .personalRecord,
                    title: String(localized: "Personal Record Updated"),
                    detail: "\(activityName): \(prTypeNames)",
                    pointsAwarded: prPoints,
                    levelAfterEvent: nil
                )
            )

            var unlockedPRBadgeCount = 0
            for type in uniquePRTypes {
                let badgeKey = "pr-\(workout.activityType.rawValue)-\(type.rawValue)"
                if !state.unlockedBadges.contains(badgeKey) {
                    state.unlockedBadges.append(badgeKey)
                    unlockedPRBadgeCount += 1
                }
            }

            if unlockedPRBadgeCount > 0 {
                let detail: String = unlockedPRBadgeCount == 1
                    ? String(localized: "1 new PR badge unlocked")
                    : String(localized: "\(unlockedPRBadgeCount) new PR badges unlocked")
                newEvents.append(
                    WorkoutRewardEvent(
                        id: "badge-pr-\(workout.id)-\(prTypeSignature)",
                        workoutID: workout.id,
                        activityTypeRawValue: workout.activityType.rawValue,
                        date: eventDate,
                        kind: .badgeUnlocked,
                        title: String(localized: "New Badge Unlocked"),
                        detail: detail,
                        pointsAwarded: 0,
                        levelAfterEvent: nil
                    )
                )
            }
        }

        if sessionPoints > 0 {
            state.totalPoints += sessionPoints
            let previousLevel = max(state.level, 1)
            let calculatedLevel = max(1, (state.totalPoints / RewardPoints.pointsPerLevel) + 1)
            state.level = calculatedLevel

            if calculatedLevel > previousLevel {
                newEvents.append(
                    WorkoutRewardEvent(
                        id: "level-\(workout.id)-\(calculatedLevel)",
                        workoutID: workout.id,
                        activityTypeRawValue: workout.activityType.rawValue,
                        date: eventDate,
                        kind: .levelUp,
                        title: String(localized: "Level Up!"),
                        detail: String(localized: "Reached Level \(calculatedLevel)"),
                        pointsAwarded: 0,
                        levelAfterEvent: calculatedLevel
                    )
                )
            }
        }

        if !newEvents.isEmpty {
            var existingIDs = Set(state.history.map(\.id))
            for event in newEvents where existingIDs.insert(event.id).inserted {
                state.history.append(event)
            }
            state.history.sort { $0.date > $1.date }
            if state.history.count > Self.maxRewardHistoryEntries {
                state.history = Array(state.history.prefix(Self.maxRewardHistoryEntries))
            }
        }

        state.processedWorkoutSignatures[workout.id] = signature
        trimProcessedWorkoutSignatures(&state)
        saveRewardState(state)

        return WorkoutRewardOutcome(
            events: newEvents,
            representativeEvent: selectRepresentativeEvent(from: newEvents),
            summary: summary(from: state)
        )
    }

    // MARK: - Private (Records)

    private func saveRecords(_ records: [PersonalRecordType: PersonalRecord], for activityType: WorkoutActivityType) {
        let key = recordKeyPrefix + activityType.rawValue
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
    }

    // MARK: - Private (Rewards)

    private func loadRewardState() -> RewardState {
        guard let data = defaults.data(forKey: rewardStateKey),
              let decoded = try? JSONDecoder().decode(RewardState.self, from: data) else {
            return RewardState()
        }
        return decoded
    }

    private func saveRewardState(_ state: RewardState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: rewardStateKey)
    }

    private func summary(from state: RewardState) -> WorkoutRewardSummary {
        WorkoutRewardSummary(
            level: max(state.level, 1),
            totalPoints: max(state.totalPoints, 0),
            badgeCount: state.unlockedBadges.count
        )
    }

    private func rewardSignature(
        activityType: WorkoutActivityType,
        milestone: WorkoutMilestoneAchievement?,
        newPRTypes: [PersonalRecordType]
    ) -> String {
        let milestonePart = milestone?.key ?? "none"
        let prPart = Array(Set(newPRTypes))
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
        return "\(activityType.rawValue)|\(milestonePart)|\(prPart)"
    }

    private func selectRepresentativeEvent(from events: [WorkoutRewardEvent]) -> WorkoutRewardEvent? {
        events.max { lhs, rhs in
            if lhs.kind.priority != rhs.kind.priority {
                return lhs.kind.priority < rhs.kind.priority
            }
            if lhs.pointsAwarded != rhs.pointsAwarded {
                return lhs.pointsAwarded < rhs.pointsAwarded
            }
            return lhs.id < rhs.id
        }
    }

    private func prDisplayName(for type: PersonalRecordType) -> String {
        switch type {
        case .fastestPace: String(localized: "Fastest Pace")
        case .longestDistance: String(localized: "Longest Distance")
        case .highestCalories: String(localized: "Highest Calories")
        case .longestDuration: String(localized: "Longest Duration")
        case .highestElevation: String(localized: "Highest Elevation")
        }
    }

    private func trimProcessedWorkoutSignatures(_ state: inout RewardState) {
        guard state.processedWorkoutSignatures.count > Self.maxProcessedWorkoutEntries else { return }

        let overflow = state.processedWorkoutSignatures.count - Self.maxProcessedWorkoutEntries
        let keysToRemove = state.processedWorkoutSignatures.keys.sorted().prefix(overflow)
        for key in keysToRemove {
            state.processedWorkoutSignatures.removeValue(forKey: key)
        }
    }
}
