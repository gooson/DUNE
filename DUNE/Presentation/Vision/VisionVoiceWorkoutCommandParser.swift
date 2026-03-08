import Foundation

enum VisionVoiceWorkoutParseResult: Equatable, Sendable {
    case success(VisionVoiceWorkoutDraft)
    case failure(String)
}

enum VisionVoiceDistanceUnit: String, Equatable, Sendable {
    case km
    case meters
    case miles

    var displayName: String {
        switch self {
        case .km:
            String(localized: "km")
        case .meters:
            String(localized: "m")
        case .miles:
            String(localized: "mi")
        }
    }
}

struct VisionVoiceWorkoutDraft: Equatable, Sendable {
    let transcript: String
    let exercise: ExerciseDefinition
    let reps: Int?
    let weight: Double?
    let weightUnit: WeightUnit?
    let durationSeconds: TimeInterval?
    let distance: Double?
    let distanceUnit: VisionVoiceDistanceUnit?
    let notes: [String]

    func primaryDisplayName(locale: Locale = .autoupdatingCurrent) -> String {
        if locale.identifier.hasPrefix("ko"), !exercise.localizedName.isEmpty {
            return exercise.localizedName
        }
        return exercise.name
    }

    func secondaryDisplayName(locale: Locale = .autoupdatingCurrent) -> String? {
        guard locale.identifier.hasPrefix("ko"), exercise.localizedName != exercise.name else {
            return nil
        }
        return exercise.name
    }
}

struct VisionVoiceWorkoutCommandParser {
    private let library: any ExerciseLibraryQuerying

    init(library: any ExerciseLibraryQuerying = ExerciseLibraryService.shared) {
        self.library = library
    }

    func parse(_ transcript: String) -> VisionVoiceWorkoutParseResult {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else {
            return .failure(String(localized: "Add an exercise name to the transcript first."))
        }

        let extracted = extractMetrics(from: trimmedTranscript)
        let exerciseQuery = cleanupExerciseQuery(from: extracted.remainingTranscript)

        guard !exerciseQuery.isEmpty else {
            return .failure(String(localized: "Add an exercise name to the transcript first."))
        }

        guard let exercise = matchExercise(for: exerciseQuery) else {
            return .failure(String(localized: "We could not match that exercise yet."))
        }

        var reps = extracted.reps
        var weight = extracted.weight
        var weightUnit = extracted.weightUnit
        var durationSeconds = extracted.durationSeconds
        let distance = extracted.distance
        let distanceUnit = extracted.distanceUnit
        var notes: [String] = []

        switch exercise.inputType {
        case .setsRepsWeight:
            if reps == nil, extracted.residualNumbers.count >= 2 {
                weight = weight ?? extracted.residualNumbers[0]
                weightUnit = weightUnit ?? .kg
                reps = Int(extracted.residualNumbers[1])
                notes.append(String(localized: "Weight unit was assumed as kg for this draft."))
            } else if reps == nil, let inferredReps = extracted.residualNumbers.last {
                reps = Int(inferredReps)
                notes.append(String(localized: "The final number was treated as reps."))
            }

            guard let reps, reps > 0 else {
                return .failure(String(localized: "Add reps for this exercise draft."))
            }

        case .setsReps:
            if reps == nil, let inferredReps = extracted.residualNumbers.last {
                reps = Int(inferredReps)
                notes.append(String(localized: "The final number was treated as reps."))
            }

            guard let reps, reps > 0 else {
                return .failure(String(localized: "Add reps for this exercise draft."))
            }

        case .durationDistance:
            if durationSeconds == nil, distance != nil, let inferredMinutes = extracted.residualNumbers.first {
                durationSeconds = inferredMinutes * 60
                notes.append(String(localized: "The remaining number was treated as minutes."))
            } else if durationSeconds == nil,
                      distance == nil,
                      extracted.residualNumbers.count == 1,
                      let inferredMinutes = extracted.residualNumbers.first {
                durationSeconds = inferredMinutes * 60
                notes.append(String(localized: "The remaining number was treated as minutes."))
            }

            guard durationSeconds != nil || distance != nil else {
                return .failure(String(localized: "Add duration or distance for this cardio draft."))
            }

        case .durationIntensity:
            if durationSeconds == nil, let inferredMinutes = extracted.residualNumbers.first {
                durationSeconds = inferredMinutes * 60
                notes.append(String(localized: "The remaining number was treated as minutes."))
            }

            guard durationSeconds != nil else {
                return .failure(String(localized: "Add duration for this workout draft."))
            }

        case .roundsBased:
            if reps == nil, let inferredRounds = extracted.residualNumbers.last {
                reps = Int(inferredRounds)
                notes.append(String(localized: "The final number was treated as rounds."))
            }

            guard let reps, reps > 0 else {
                return .failure(String(localized: "Add rounds for this workout draft."))
            }
        }

        return .success(
            VisionVoiceWorkoutDraft(
                transcript: trimmedTranscript,
                exercise: exercise,
                reps: reps,
                weight: weight,
                weightUnit: weightUnit,
                durationSeconds: durationSeconds,
                distance: distance,
                distanceUnit: distanceUnit,
                notes: notes
            )
        )
    }

    private func extractMetrics(from transcript: String) -> ExtractedMetrics {
        var remainingTranscript = normalizedText(transcript)

        let weightMatch = Self.firstMatch(for: Self.weightPattern, in: remainingTranscript)
        let weight = weightMatch.flatMap { Double(Self.capture(group: 1, from: remainingTranscript, match: $0) ?? "") }
        let weightUnit = weightMatch.flatMap {
            guard let token = Self.capture(group: 2, from: remainingTranscript, match: $0) else { return nil }
            return Self.weightUnit(for: token)
        }
        Self.remove(match: weightMatch, from: &remainingTranscript)

        let repsMatch = Self.firstMatch(for: Self.repsPattern, in: remainingTranscript)
        let reps = repsMatch.flatMap { Int(Self.capture(group: 1, from: remainingTranscript, match: $0) ?? "") }
        Self.remove(match: repsMatch, from: &remainingTranscript)

        let durationMatch = Self.firstMatch(for: Self.durationPattern, in: remainingTranscript)
        let durationValue = durationMatch.flatMap { Double(Self.capture(group: 1, from: remainingTranscript, match: $0) ?? "") }
        let durationSeconds = durationMatch.flatMap {
            guard let token = Self.capture(group: 2, from: remainingTranscript, match: $0),
                  let durationValue
            else { return nil }
            return Self.durationSeconds(for: durationValue, unitToken: token)
        }
        Self.remove(match: durationMatch, from: &remainingTranscript)

        let distanceMatch = Self.firstMatch(for: Self.distancePattern, in: remainingTranscript)
        let distance = distanceMatch.flatMap { Double(Self.capture(group: 1, from: remainingTranscript, match: $0) ?? "") }
        let distanceUnit = distanceMatch.flatMap {
            guard let token = Self.capture(group: 2, from: remainingTranscript, match: $0) else { return nil }
            return Self.distanceUnit(for: token)
        }
        Self.remove(match: distanceMatch, from: &remainingTranscript)

        return ExtractedMetrics(
            remainingTranscript: remainingTranscript,
            reps: reps,
            weight: weight,
            weightUnit: weightUnit,
            durationSeconds: durationSeconds,
            distance: distance,
            distanceUnit: distanceUnit,
            residualNumbers: standaloneNumbers(in: remainingTranscript)
        )
    }

    private func cleanupExerciseQuery(from transcript: String) -> String {
        let noNumbers = transcript.replacingOccurrences(
            of: Self.numberPattern,
            with: " ",
            options: .regularExpression
        )

        let tokens = noNumbers
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !Self.fillerTokens.contains($0) }

        return tokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func standaloneNumbers(in transcript: String) -> [Double] {
        Self.matches(for: Self.numberPattern, in: transcript).compactMap {
            Double(Self.capture(group: 1, from: transcript, match: $0) ?? "")
        }
    }

    private func matchExercise(for query: String) -> ExerciseDefinition? {
        let normalizedQuery = normalizedSearchText(query)
        guard !normalizedQuery.isEmpty else { return nil }

        var bestMatch: (score: Int, exercise: ExerciseDefinition)?

        for exercise in library.allExercises() {
            let score = candidateLabels(for: exercise)
                .map { score(query: normalizedQuery, against: $0) }
                .max() ?? 0

            guard score > 0 else { continue }

            if let existing = bestMatch {
                if score > existing.score {
                    bestMatch = (score, exercise)
                }
            } else {
                bestMatch = (score, exercise)
            }
        }

        return bestMatch?.exercise
    }

    private func candidateLabels(for exercise: ExerciseDefinition) -> [String] {
        ([exercise.name, exercise.localizedName] + (exercise.aliases ?? []))
            .map(normalizedSearchText)
            .filter { !$0.isEmpty }
    }

    private func score(query: String, against label: String) -> Int {
        guard !label.isEmpty else { return 0 }
        if label == query {
            return 1_000 + label.count
        }
        if label.contains(query) {
            return 800 + query.count
        }
        if query.contains(label) {
            return 700 + label.count
        }

        let queryTokens = Set(query.split(separator: " ").map(String.init))
        let labelTokens = Set(label.split(separator: " ").map(String.init))

        if !queryTokens.isEmpty, queryTokens.isSubset(of: labelTokens) {
            return 600 + queryTokens.count * 10
        }
        if !labelTokens.isEmpty, labelTokens.isSubset(of: queryTokens) {
            return 500 + labelTokens.count * 10
        }

        let overlap = queryTokens.intersection(labelTokens).count
        if overlap > 0 {
            return 300 + overlap * 10
        }

        return 0
    }

    private func normalizedText(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(
                of: #"[^\p{L}\p{N}\s\.]"#,
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedSearchText(_ text: String) -> String {
        normalizedText(text)
    }

    private static func weightUnit(for token: String) -> WeightUnit? {
        let normalized = token.lowercased()
        if ["kg", "kgs", "kilogram", "kilograms", "킬로그램", "키로그램", "킬로", "키로"].contains(normalized) {
            return .kg
        }
        if ["lb", "lbs", "pound", "pounds", "파운드"].contains(normalized) {
            return .lb
        }
        return nil
    }

    private static func durationSeconds(for value: Double, unitToken: String) -> TimeInterval? {
        let normalized = unitToken.lowercased()
        switch normalized {
        case "hour", "hours", "hr", "hrs", "시간":
            return value * 3600
        case "minute", "minutes", "min", "mins", "분":
            return value * 60
        case "second", "seconds", "sec", "secs", "초":
            return value
        default:
            return nil
        }
    }

    private static func distanceUnit(for token: String) -> VisionVoiceDistanceUnit? {
        let normalized = token.lowercased()
        switch normalized {
        case "km", "kms", "kilometer", "kilometers", "킬로미터", "키로미터":
            .km
        case "meter", "meters", "미터":
            .meters
        case "mile", "miles", "마일":
            .miles
        default:
            nil
        }
    }

    private static func firstMatch(
        for pattern: String,
        in text: String
    ) -> NSTextCheckingResult? {
        matches(for: pattern, in: text).first
    }

    private static func matches(
        for pattern: String,
        in text: String
    ) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private static func capture(
        group: Int,
        from text: String,
        match: NSTextCheckingResult
    ) -> String? {
        guard let range = Range(match.range(at: group), in: text) else { return nil }
        return String(text[range])
    }

    private static func remove(
        match: NSTextCheckingResult?,
        from text: inout String
    ) {
        guard let match, let range = Range(match.range, in: text) else { return }
        text.replaceSubrange(range, with: " ")
        text = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let fillerTokens: Set<String> = [
        "log",
        "logged",
        "record",
        "recorded",
        "save",
        "saved",
        "workout",
        "exercise",
        "운동",
        "기록",
        "입력",
        "추가",
        "했어",
        "했어요",
        "했음",
    ]

    private static let weightPattern =
        #"(?<!\d)(\d+(?:\.\d+)?)\s*(kg|kgs|kilograms?|킬로그램|키로그램|킬로(?!미터)|키로(?!미터)|lb|lbs|pounds?|파운드)"#
    private static let repsPattern =
        #"(?<!\d)(\d+)\s*(rep|reps|회|번)"#
    private static let durationPattern =
        #"(?<!\d)(\d+(?:\.\d+)?)\s*(hour|hours|hr|hrs|시간|minute|minutes|min|mins|분|second|seconds|sec|secs|초)"#
    private static let distancePattern =
        #"(?<!\d)(\d+(?:\.\d+)?)\s*(km|kms|kilometer|kilometers|킬로미터|키로미터|meter|meters|미터|mile|miles|마일)"#
    private static let numberPattern =
        #"(?<![\p{L}\d])(\d+(?:\.\d+)?)"#
}

private struct ExtractedMetrics {
    let remainingTranscript: String
    let reps: Int?
    let weight: Double?
    let weightUnit: WeightUnit?
    let durationSeconds: TimeInterval?
    let distance: Double?
    let distanceUnit: VisionVoiceDistanceUnit?
    let residualNumbers: [Double]
}
