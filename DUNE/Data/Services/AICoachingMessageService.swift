import Foundation
import FoundationModels

/// Enhances coaching insight messages using Apple's on-device Foundation Models.
/// Falls back to the original template message on unsupported devices or errors.
struct AICoachingMessageService: CoachingMessageEnhancing, Sendable {

    /// Whether Foundation Models are available on this device.
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    private let availabilityProvider: @Sendable () -> Bool

    init(
        availabilityProvider: @escaping @Sendable () -> Bool = { AICoachingMessageService.isAvailable }
    ) {
        self.availabilityProvider = availabilityProvider
    }

    func enhance(insight: CoachingInsight, context: CoachingInput) async -> CoachingInsight {
        guard availabilityProvider() else { return insight }

        do {
            let session = LanguageModelSession()
            let prompt = buildPrompt(insight: insight, context: context)
            let response = try await session.respond(
                to: prompt,
                generating: AICoachingMessage.self
            )

            let title = String(response.content.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(50))
            let message = String(response.content.message
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(200))

            guard !message.isEmpty else { return insight }

            return CoachingInsight(
                id: insight.id,
                priority: insight.priority,
                category: insight.category,
                title: title.isEmpty ? insight.title : title,
                message: message,
                iconName: insight.iconName,
                actionHint: insight.actionHint
            )
        } catch {
            return insight
        }
    }

    // MARK: - Prompt Construction

    func buildPrompt(insight: CoachingInsight, context: CoachingInput) -> String {
        var lines: [String] = []

        let languageInstruction = Self.localeInstruction()
        lines.append(languageInstruction)
        lines.append("")

        // Context data
        lines.append("User context:")
        if let score = context.conditionScore {
            lines.append("- Condition: \(score.score)/100 (\(score.status.rawValue))")
        }
        if let sleepMinutes = context.sleepMinutes {
            let hours = Int(sleepMinutes) / 60
            let mins = Int(sleepMinutes) % 60
            lines.append("- Sleep: \(hours)h \(mins)m")
        }
        lines.append("- Active days this week: \(context.activeDaysThisWeek)/\(context.weeklyGoalDays)")
        if let days = context.daysSinceLastWorkout {
            lines.append("- Days since last workout: \(days)")
        }
        if let streak = context.workoutStreak {
            lines.append("- Streak: \(streak.currentStreak) days")
        }

        lines.append("")
        lines.append("Category: \(insight.category.rawValue)")
        lines.append("Priority: \(insight.priority.rawValue)")
        lines.append("Template message: \(insight.message)")

        return lines.joined(separator: "\n")
    }

    /// Returns a locale-appropriate instruction prefix for the prompt.
    private static func localeInstruction() -> String {
        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        switch langCode {
        case "ko":
            return "건강 앱의 코칭 메시지를 한국어로 작성해주세요. 따뜻하고 공감적인 톤으로 1-2문장으로 작성하세요. 행동 가능한 조언을 포함하세요."
        case "ja":
            return "ヘルスアプリのコーチングメッセージを日本語で作成してください。温かく共感的なトーンで1-2文で書いてください。実行可能なアドバイスを含めてください。"
        default:
            return "Write a personalized coaching message for a health & fitness app.\nUse a warm, empathetic tone. Keep it to 1-2 sentences. Include actionable advice."
        }
    }
}

// MARK: - Generable Types

@Generable(description: "A personalized coaching message for a health and fitness app user")
struct AICoachingMessage {
    @Guide(description: "A warm, encouraging title in 3-6 words")
    var title: String

    @Guide(description: "A personalized coaching message in 1-2 sentences, empathetic and actionable")
    var message: String
}
