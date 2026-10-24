import Foundation

enum ExerciseMixService {
    /// The same merged exercise-record unit drives every section of the summary and detail.
    /// An explicitly linked workout wins first; app workouts without a link use the existing
    /// name and two-minute recovery match. Third-party workouts are never proximity-deduped.
    static func analyze(
        _ entries: [ExerciseMixEntry],
        asOf date: Date = .now,
        calendar: Calendar = .current
    ) -> ExerciseMixSummary {
        let end = date
        let today = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .day, value: -27, to: today) ?? today
        let active = entries.filter {
            start <= $0.date && $0.date <= end
                && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let manual = active.filter { !$0.isHealthKit }
        let linked = Set(manual.compactMap(\.linkedWorkoutID))
        var seen = Set<String>()
        let merged = active.filter { entry in
            guard seen.insert(entry.id).inserted else { return false }
            guard entry.isHealthKit else { return true }
            if linked.contains(entry.id) { return false }
            // Only app-created workouts enter this fallback path: their caller sets the
            // linkedWorkoutID to their own ID. External workouts keep it nil.
            if entry.linkedWorkoutID != nil {
                return !manual.contains {
                    ($0.dedupName ?? $0.name).caseInsensitiveCompare(entry.dedupName ?? entry.name) == .orderedSame
                        && abs($0.date.timeIntervalSince(entry.date)) < 120
                }
            }
            return true
        }

        let strength = merged.filter { $0.kind == .strength }
        let cardio = merged.filter { $0.kind == .cardio }
        let other = merged.filter { $0.kind == .other }
        let weeks = (0..<4).map { index -> ExerciseMixSummary.Week in
            let weekStart = calendar.date(byAdding: .day, value: index * 7, to: start) ?? start
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? end
            let week = merged.filter { $0.date >= weekStart && $0.date < weekEnd }
            return .init(index: index, start: weekStart,
                         strength: week.filter { $0.kind == .strength }.count,
                         cardio: week.filter { $0.kind == .cardio }.count,
                         other: week.filter { $0.kind == .other }.count)
        }

        var muscleSets: [MuscleGroup: Double] = [:]
        var unattributed = 0
        for entry in strength where entry.completedSets > 0 {
            let muscles = Array(Set(entry.primaryMuscles)).sorted { $0.rawValue < $1.rawValue }
            guard !muscles.isEmpty else {
                unattributed += entry.completedSets
                continue
            }
            let share = Double(entry.completedSets) / Double(muscles.count)
            for muscle in muscles { muscleSets[muscle, default: 0] += share }
        }
        let attributedTotal = muscleSets.values.reduce(0, +)
        var muscleShares: [ExerciseMixSummary.MuscleShare] = []
        for (muscle, sets) in muscleSets {
            muscleShares.append(.init(muscle: muscle, sets: sets,
                                      fraction: attributedTotal > 0 ? sets / attributedTotal : 0))
        }
        muscleShares.sort {
            if $0.sets == $1.sets { return $0.muscle.rawValue < $1.muscle.rawValue }
            return $0.sets > $1.sets
        }

        let cardioGroups = Dictionary(grouping: cardio, by: \.name)
        var cardioTypes: [ExerciseMixSummary.CardioType] = []
        for (name, group) in cardioGroups {
            let durations = group.compactMap(\.durationMinutes).filter { $0 > 0 && $0.isFinite }
            let distances = group.compactMap(\.distanceKm).filter { $0 > 0 && $0.isFinite }
            cardioTypes.append(.init(name: name, count: group.count,
                                     durationMinutes: durations.isEmpty ? nil : durations.reduce(0, +),
                                     distanceKm: distances.isEmpty ? nil : distances.reduce(0, +)))
        }
        cardioTypes.sort {
            if $0.count == $1.count { return $0.name < $1.name }
            return $0.count > $1.count
        }

        let frequencyEntries = merged.map { ExerciseFrequencyService.WorkoutEntry(exerciseName: $0.name, date: $0.date) }
        return ExerciseMixSummary(start: start, end: end, strength: strength.count, cardio: cardio.count,
                                  other: other.count, weeks: weeks, muscles: muscleShares,
                                  unattributedSets: unattributed, cardioTypes: cardioTypes,
                                  frequencies: ExerciseFrequencyService.analyze(from: frequencyEntries))
    }
}
