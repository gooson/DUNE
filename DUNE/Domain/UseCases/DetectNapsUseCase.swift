import Foundation

protocol NapDetecting: Sendable {
    func execute(input: DetectNapsUseCase.Input) -> NapAnalysis
}

/// Detects daytime naps (06:00-20:00, >= 30 min) from sleep stage data.
struct DetectNapsUseCase: NapDetecting, Sendable {

    struct Input: Sendable {
        let sleepStagesByDay: [[SleepStage]]
        let calendar: Calendar
        let analysisDays: Int

        init(sleepStagesByDay: [[SleepStage]], calendar: Calendar = .current, analysisDays: Int = 14) {
            self.sleepStagesByDay = sleepStagesByDay
            self.calendar = calendar
            self.analysisDays = analysisDays
        }
    }

    /// Minimum nap duration to count (minutes).
    private let minimumDurationMinutes: Double = 30.0

    /// Daytime window: 06:00-20:00.
    private let daytimeStartHour = 6
    private let daytimeEndHour = 20

    func execute(input: Input) -> NapAnalysis {
        let allStages = input.sleepStagesByDay.flatMap { $0 }
        let sessions = buildSleepSessions(from: allStages, calendar: input.calendar)

        let naps = sessions.compactMap { session -> NapAnalysis.DetectedNap? in
            let duration = session.end.timeIntervalSince(session.start) / 60.0
            guard duration >= minimumDurationMinutes else { return nil }

            let midpoint = session.start.addingTimeInterval(session.end.timeIntervalSince(session.start) / 2)
            let hour = input.calendar.component(.hour, from: midpoint)
            guard hour >= daytimeStartHour, hour < daytimeEndHour else { return nil }

            return .init(
                id: UUID(),
                startDate: session.start,
                endDate: session.end,
                durationMinutes: duration
            )
        }

        let averageDuration: Double? = naps.isEmpty ? nil : naps.map(\.durationMinutes).reduce(0, +) / Double(naps.count)
        let frequency: Double? = input.analysisDays >= 7
            ? Double(naps.count) / Double(input.analysisDays) * 7.0
            : nil

        return NapAnalysis(
            naps: naps,
            averageDurationMinutes: averageDuration,
            frequencyPerWeek: frequency,
            analysisDays: input.analysisDays
        )
    }

    /// Groups contiguous non-awake stages into sleep sessions.
    private func buildSleepSessions(from stages: [SleepStage], calendar: Calendar) -> [(start: Date, end: Date)] {
        let sleepStages = stages
            .filter { $0.stage != .awake }
            .sorted { $0.startDate < $1.startDate }

        guard !sleepStages.isEmpty else { return [] }

        var sessions: [(start: Date, end: Date)] = []
        var currentStart = sleepStages[0].startDate
        var currentEnd = sleepStages[0].endDate

        for stage in sleepStages.dropFirst() {
            // Gap > 30 min means new session
            if stage.startDate.timeIntervalSince(currentEnd) > 30 * 60 {
                sessions.append((start: currentStart, end: currentEnd))
                currentStart = stage.startDate
                currentEnd = stage.endDate
            } else {
                currentEnd = max(currentEnd, stage.endDate)
            }
        }
        sessions.append((start: currentStart, end: currentEnd))

        return sessions
    }
}
