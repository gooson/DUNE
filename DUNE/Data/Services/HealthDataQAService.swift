import Foundation
import FoundationModels

actor HealthDataQAService: HealthDataQuestionAnswering {
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    static func defaultAvailabilityProvider() -> Bool {
        isAvailable
    }

    private let contextBuilder: HealthDataQAContextBuilder
    private let nowProvider: @Sendable () -> Date
    private let availabilityProvider: @Sendable () -> Bool
    private var session: LanguageModelSession?

    init(
        sharedHealthDataService: SharedHealthDataService?,
        sleepService: any SleepQuerying = SleepQueryService(manager: .shared),
        workoutService: any WorkoutQuerying = WorkoutQueryService(manager: .shared),
        hrvService: any HRVQuerying = HRVQueryService(manager: .shared),
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        availabilityProvider: @escaping @Sendable () -> Bool = HealthDataQAService.defaultAvailabilityProvider
    ) {
        self.contextBuilder = HealthDataQAContextBuilder(
            sharedHealthDataService: sharedHealthDataService,
            sleepService: sleepService,
            workoutService: workoutService,
            hrvService: hrvService,
            nowProvider: nowProvider
        )
        self.availabilityProvider = availabilityProvider
        self.nowProvider = nowProvider
    }

    func ask(_ question: String) async -> HealthDataQAReply {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            return HealthDataQAReply(
                text: String(localized: "Ask a question about your sleep, recovery, or workouts."),
                generatedAt: nowProvider(),
                isFallback: true
            )
        }

        guard availabilityProvider() else {
            return unsupportedReply()
        }

        do {
            let session = try await activeSession()
            let response = try await session.respond(
                to: trimmedQuestion,
                options: GenerationOptions(
                    sampling: .greedy,
                    temperature: 0.2,
                    maximumResponseTokens: 220
                )
            )
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return failureReply() }
            return HealthDataQAReply(text: text, generatedAt: nowProvider(), isFallback: false)
        } catch {
            return failureReply()
        }
    }

    func resetConversation() async {
        session = nil
    }

    func makeInstructions() async -> String {
        let baselineSummary = await contextBuilder.makeBaselineSummary()
        return """
        \(Self.localeInstruction())

        You are DUNE's on-device health data assistant.
        Use the available tools whenever the user asks about sleep, recovery, workouts, readiness, HRV, or resting heart rate.
        Only answer from the user's recent app data and tool outputs.
        Keep answers short and practical, usually 2-4 sentences.
        If data is missing, say so plainly instead of guessing.
        Do not provide diagnosis, treatment, or medical certainty.
        If the user asks why something changed, explain only the patterns visible in the available data.

        Current baseline summary:
        \(baselineSummary)
        """
    }

    func makeBaselineSummary() async -> String {
        await contextBuilder.makeBaselineSummary()
    }

    func makeConditionSummary(days: Int) async -> String {
        await contextBuilder.makeConditionSummary(days: days)
    }

    func makeSleepSummary(days: Int) async -> String {
        await contextBuilder.makeSleepSummary(days: days)
    }

    func makeWorkoutSummary(days: Int) async -> String {
        await contextBuilder.makeWorkoutSummary(days: days)
    }

    func makeRecoverySummary(days: Int) async -> String {
        await contextBuilder.makeRecoverySummary(days: days)
    }

    private func activeSession() async throws -> LanguageModelSession {
        if let session {
            return session
        }

        let instructions = await makeInstructions()
        let tools: [any Tool] = [
            ConditionSummaryTool(contextBuilder: contextBuilder),
            SleepSummaryTool(contextBuilder: contextBuilder),
            WorkoutSummaryTool(contextBuilder: contextBuilder),
            RecoverySummaryTool(contextBuilder: contextBuilder)
        ]
        let newSession = LanguageModelSession(tools: tools, instructions: instructions)
        session = newSession
        return newSession
    }

    private func unsupportedReply() -> HealthDataQAReply {
        HealthDataQAReply(
            text: String(localized: "Health Q&A requires Apple Intelligence on a supported device."),
            generatedAt: nowProvider(),
            isFallback: true
        )
    }

    private func failureReply() -> HealthDataQAReply {
        HealthDataQAReply(
            text: String(localized: "I couldn't answer that right now. Try asking about sleep, recovery, or recent workouts."),
            generatedAt: nowProvider(),
            isFallback: true
        )
    }

    private static func localeInstruction() -> String {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        switch languageCode {
        case "ko":
            return "사용자의 최근 건강 데이터를 바탕으로 한국어로 간결하게 답변하세요."
        case "ja":
            return "ユーザーの最近のヘルスデータに基づいて、日本語で簡潔に回答してください。"
        default:
            return "Answer in the user's current language using concise, plain wording."
        }
    }
}

struct HealthDataQAContextBuilder: Sendable {
    let sharedHealthDataService: SharedHealthDataService?
    let sleepService: any SleepQuerying
    let workoutService: any WorkoutQuerying
    let hrvService: any HRVQuerying
    let nowProvider: @Sendable () -> Date

    private var calendar: Calendar { .current }

    func makeBaselineSummary() async -> String {
        guard let snapshot = await sharedHealthDataService?.fetchSnapshot() else {
            return "No shared health snapshot is available yet."
        }

        var lines: [String] = [
            "- Snapshot captured: \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))"
        ]

        if let condition = snapshot.conditionScore {
            lines.append("- Current condition: \(condition.score)/100 (\(condition.status.rawValue))")
        } else if let baselineStatus = snapshot.baselineStatus {
            lines.append("- Condition score unavailable: baseline collection \(baselineStatus.daysCollected)/\(baselineStatus.daysRequired) days")
        } else {
            lines.append("- Condition score unavailable")
        }

        let recentScores = scores(from: snapshot, withinDays: 7)
        if recentScores.count >= 2 {
            let values = recentScores.map { Double($0.score) }
            lines.append("- 7-day condition trend: \(trendDescription(for: values, threshold: 2))")
            if let averageScore = average(values) {
                lines.append("- 7-day condition average: \(Int(averageScore.rounded()))")
            }
        }

        let recentSleep = sleepDurations(from: snapshot, withinDays: 7)
        if let lastSleep = recentSleep.last?.totalMinutes {
            lines.append("- Last recorded sleep: \(hoursAndMinutesString(lastSleep))")
        }
        if let averageSleep = average(recentSleep.map(\.totalMinutes)) {
            lines.append("- 7-day sleep average: \(hoursAndMinutesString(averageSleep))")
        }

        if let effectiveRHR = snapshot.effectiveRHR {
            let historicalSuffix = effectiveRHR.isHistorical ? " (historical sample)" : ""
            lines.append("- Resting heart rate: \(numberString(effectiveRHR.value, fractionDigits: 0)) bpm\(historicalSuffix)")
        }

        if let averageHRV = average(snapshot.hrvSamples14Day.map(\.value)) {
            lines.append("- 14-day HRV average: \(numberString(averageHRV, fractionDigits: 0)) ms")
        }

        if !snapshot.failedSources.isEmpty {
            lines.append("- Missing sources: \(snapshot.failedSources.count)")
        }

        return lines.joined(separator: "\n")
    }

    func makeConditionSummary(days: Int) async -> String {
        guard let snapshot = await sharedHealthDataService?.fetchSnapshot() else {
            return "Condition summary is unavailable because no shared health snapshot exists yet."
        }

        let boundedDays = min(max(days, 1), 14)
        let recentScores = scores(from: snapshot, withinDays: boundedDays)
        guard !recentScores.isEmpty || snapshot.conditionScore != nil else {
            return "No condition or readiness score is available yet."
        }

        var lines = ["Condition summary for the last \(boundedDays) days:"]

        if let current = snapshot.conditionScore {
            lines.append("- Current score: \(current.score)/100 (\(current.status.rawValue))")
            if let detail = current.detail {
                let delta = detail.todayHRV - detail.baselineHRV
                let direction = delta >= 0 ? "above" : "below"
                lines.append("- HRV is \(numberString(abs(delta), fractionDigits: 0)) ms \(direction) baseline")
                if detail.rhrPenalty > 0 {
                    lines.append("- Resting heart rate penalty: \(numberString(detail.rhrPenalty, fractionDigits: 1)) points")
                }
            }
        }

        if !recentScores.isEmpty {
            let values = recentScores.map { Double($0.score) }
            if let averageScore = average(values),
               let highest = values.max(),
               let lowest = values.min() {
                lines.append("- Average: \(Int(averageScore.rounded()))")
                lines.append("- Range: \(Int(lowest.rounded())) to \(Int(highest.rounded()))")
                lines.append("- Trend: \(trendDescription(for: values, threshold: 2))")
            }
        }

        return lines.joined(separator: "\n")
    }

    func makeSleepSummary(days: Int) async -> String {
        let boundedDays = min(max(days, 1), 14)
        let endDate = nowProvider()
        let startDate = calendar.date(byAdding: .day, value: -(boundedDays - 1), to: calendar.startOfDay(for: endDate))
            ?? calendar.startOfDay(for: endDate)
        let queryEndDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))
            ?? endDate

        var sleepDurations: [SharedHealthSnapshot.SleepDailyDuration] = []
        if let snapshot = await sharedHealthDataService?.fetchSnapshot() {
            sleepDurations = self.sleepDurations(from: snapshot, withinDays: boundedDays)
        }

        if sleepDurations.isEmpty {
            do {
                let fetched = try await sleepService.fetchDailySleepDurations(start: startDate, end: queryEndDate)
                sleepDurations = fetched.map {
                    SharedHealthSnapshot.SleepDailyDuration(
                        date: $0.date,
                        totalMinutes: $0.totalMinutes,
                        stageBreakdown: $0.stageBreakdown
                    )
                }
            } catch {
                sleepDurations = []
            }
        }

        guard !sleepDurations.isEmpty else {
            return "No sleep summary is available for the last \(boundedDays) days."
        }

        let values = sleepDurations.map(\.totalMinutes)
        let averageSleep = average(values) ?? 0
        let lastSleep = sleepDurations.last?.totalMinutes ?? 0
        let bestSleep = values.max() ?? 0
        let worstSleep = values.min() ?? 0

        return [
            "Sleep summary for the last \(boundedDays) days:",
            "- Last recorded sleep: \(hoursAndMinutesString(lastSleep))",
            "- Average sleep: \(hoursAndMinutesString(averageSleep))",
            "- Range: \(hoursAndMinutesString(worstSleep)) to \(hoursAndMinutesString(bestSleep))",
            "- Trend: \(trendDescription(for: values, threshold: 20))"
        ].joined(separator: "\n")
    }

    func makeWorkoutSummary(days: Int) async -> String {
        let boundedDays = min(max(days, 1), 30)
        let workouts: [WorkoutSummary]
        do {
            workouts = try await workoutService.fetchWorkouts(days: boundedDays)
                .sorted { $0.date < $1.date }
        } catch {
            return "Recent workout data could not be loaded."
        }

        guard !workouts.isEmpty else {
            return "No workouts were found in the last \(boundedDays) days."
        }

        let totalDurationMinutes = workouts.reduce(0.0) { $0 + $1.duration / 60.0 }
        let totalCalories = workouts.compactMap(\.calories).reduce(0.0, +)
        let groupedTypes = Dictionary(grouping: workouts, by: \.type)
        let topTypes = groupedTypes
            .map { (type: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.type < rhs.type }
                return lhs.count > rhs.count
            }
            .prefix(3)
            .map { "\($0.type) x\($0.count)" }
            .joined(separator: ", ")

        let lastWorkout = workouts.last
        let lastWorkoutLine: String
        if let lastWorkout {
            lastWorkoutLine = "- Last workout: \(lastWorkout.type) on \(lastWorkout.date.formatted(date: .abbreviated, time: .omitted)) for \(Int((lastWorkout.duration / 60.0).rounded())) min"
        } else {
            lastWorkoutLine = "- Last workout: unavailable"
        }

        var lines = [
            "Workout summary for the last \(boundedDays) days:",
            "- Sessions: \(workouts.count)",
            "- Total duration: \(Int(totalDurationMinutes.rounded())) min",
            lastWorkoutLine
        ]

        if !topTypes.isEmpty {
            lines.append("- Top activity types: \(topTypes)")
        }

        if totalCalories > 0 {
            lines.append("- Total active calories: \(Int(totalCalories.rounded())) kcal")
        }

        return lines.joined(separator: "\n")
    }

    func makeRecoverySummary(days: Int) async -> String {
        guard let snapshot = await sharedHealthDataService?.fetchSnapshot() else {
            return "Recovery factors are unavailable because no shared health snapshot exists yet."
        }

        let boundedDays = min(max(days, 1), 14)
        var factors: [String] = []

        if let condition = snapshot.conditionScore {
            factors.append("Current condition is \(condition.score)/100 (\(condition.status.rawValue)).")
            if let detail = condition.detail {
                let delta = detail.todayHRV - detail.baselineHRV
                let hrvDirection = delta >= 0 ? "above" : "below"
                factors.append("HRV is \(numberString(abs(delta), fractionDigits: 0)) ms \(hrvDirection) baseline.")
                if detail.rhrPenalty > 0 {
                    factors.append("Resting heart rate is contributing a \(numberString(detail.rhrPenalty, fractionDigits: 1))-point penalty.")
                }
            }
        }

        let recentSleep = sleepDurations(from: snapshot, withinDays: boundedDays)
        if let averageSleep = average(recentSleep.map(\.totalMinutes)) {
            factors.append("Average sleep over \(boundedDays) days is \(hoursAndMinutesString(averageSleep)).")
        }

        if let lastSleep = recentSleep.last?.totalMinutes {
            factors.append("Last recorded sleep was \(hoursAndMinutesString(lastSleep)).")
        }

        if let effectiveRHR = snapshot.effectiveRHR {
            let historicalSuffix = effectiveRHR.isHistorical ? " using the latest historical sample" : ""
            factors.append("Resting heart rate is \(numberString(effectiveRHR.value, fractionDigits: 0)) bpm\(historicalSuffix).")
        }

        if let averageHRV = average(snapshot.hrvSamples14Day.map(\.value)) {
            factors.append("14-day HRV average is \(numberString(averageHRV, fractionDigits: 0)) ms.")
        }

        if factors.isEmpty {
            return "No recovery factors are available yet."
        }

        return (["Recovery factors:"] + factors.map { "- \($0)" }).joined(separator: "\n")
    }

    private func scores(from snapshot: SharedHealthSnapshot, withinDays days: Int) -> [ConditionScore] {
        let cutoff = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: snapshot.fetchedAt))
            ?? calendar.startOfDay(for: snapshot.fetchedAt)

        var scores = snapshot.recentConditionScores
        if let current = snapshot.conditionScore,
           !scores.contains(where: { $0.date == current.date && $0.score == current.score }) {
            scores.append(current)
        }

        return scores
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }

    private func sleepDurations(from snapshot: SharedHealthSnapshot, withinDays days: Int) -> [SharedHealthSnapshot.SleepDailyDuration] {
        let cutoff = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: snapshot.fetchedAt))
            ?? calendar.startOfDay(for: snapshot.fetchedAt)

        return snapshot.sleepDailyDurations
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }

    private func average<S: Sequence>(_ values: S) -> Double? where S.Element == Double {
        let array = values.filter(\.isFinite)
        guard !array.isEmpty else { return nil }
        return array.reduce(0, +) / Double(array.count)
    }

    private func hoursAndMinutesString(_ minutes: Double) -> String {
        let roundedMinutes = Int(minutes.rounded())
        let hours = roundedMinutes / 60
        let remainder = roundedMinutes % 60
        return "\(hours)h \(remainder)m"
    }

    private func numberString(_ value: Double, fractionDigits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits)))
    }

    private func trendDescription(for values: [Double], threshold: Double) -> String {
        guard values.count >= 2 else { return "stable" }

        let midpoint = values.count / 2
        let leading = Array(values.prefix(max(1, midpoint)))
        let trailing = Array(values.suffix(max(1, values.count - midpoint)))
        guard let leadingAverage = average(leading),
              let trailingAverage = average(trailing) else {
            return "stable"
        }

        let delta = trailingAverage - leadingAverage
        if delta > threshold {
            return "improving"
        }
        if delta < -threshold {
            return "declining"
        }
        return "stable"
    }
}

@Generable(description: "Select how many recent days of data to summarize.")
struct HealthDataQADaysArguments {
    @Guide(description: "Number of recent days to inspect.", .range(1...30))
    let days: Int
}

struct ConditionSummaryTool: Tool {
    let name = "conditionSummary"
    let description = "Summarize recent condition or readiness scores, including HRV baseline context when available."
    let contextBuilder: HealthDataQAContextBuilder

    func call(arguments: HealthDataQADaysArguments) async throws -> String {
        await contextBuilder.makeConditionSummary(days: arguments.days)
    }
}

struct SleepSummaryTool: Tool {
    let name = "sleepSummary"
    let description = "Summarize recent sleep duration trends using compact daily totals."
    let contextBuilder: HealthDataQAContextBuilder

    func call(arguments: HealthDataQADaysArguments) async throws -> String {
        await contextBuilder.makeSleepSummary(days: arguments.days)
    }
}

struct WorkoutSummaryTool: Tool {
    let name = "workoutSummary"
    let description = "Summarize recent workouts, including session count, duration, last workout, and top activity types."
    let contextBuilder: HealthDataQAContextBuilder

    func call(arguments: HealthDataQADaysArguments) async throws -> String {
        await contextBuilder.makeWorkoutSummary(days: arguments.days)
    }
}

struct RecoverySummaryTool: Tool {
    let name = "recoverySummary"
    let description = "Summarize recent recovery factors using condition score, HRV, resting heart rate, and sleep data."
    let contextBuilder: HealthDataQAContextBuilder

    func call(arguments: HealthDataQADaysArguments) async throws -> String {
        await contextBuilder.makeRecoverySummary(days: arguments.days)
    }
}
