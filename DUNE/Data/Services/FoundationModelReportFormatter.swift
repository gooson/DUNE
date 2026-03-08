import Foundation
import FoundationModels

/// Generates natural language workout summaries using Apple's on-device Foundation Models.
/// Falls back to TemplateReportFormatter on unsupported devices.
struct FoundationModelReportFormatter: WorkoutReportFormatting, Sendable {

    private let fallback: TemplateReportFormatter

    init(fallback: TemplateReportFormatter = TemplateReportFormatter()) {
        self.fallback = fallback
    }

    /// Whether Foundation Models are available on this device.
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    func format(report: WorkoutReport) async -> String {
        guard Self.isAvailable else {
            return await fallback.format(report: report)
        }

        do {
            let session = LanguageModelSession()
            let prompt = buildPrompt(report: report)
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return await fallback.format(report: report)
            }
            return text
        } catch {
            return await fallback.format(report: report)
        }
    }

    // MARK: - Prompt Construction

    private func buildPrompt(report: WorkoutReport) -> String {
        let periodName = report.period == .weekly ? "week" : "month"
        var lines: [String] = []

        let languageInstruction = localeInstruction(periodName: periodName)
        lines.append(languageInstruction)
        lines.append("")
        lines.append("Stats:")
        lines.append("- Sessions: \(report.stats.totalSessions)")
        lines.append("- Active days: \(report.stats.activeDays)")
        lines.append("- Total volume: \(Int(report.stats.totalVolume)) kg")
        lines.append("- Total duration: \(report.stats.totalDuration) min")

        if let change = report.stats.volumeChangePercent {
            let sign = change >= 0 ? "+" : ""
            lines.append("- Volume change vs last \(periodName): \(sign)\(Int(change * 100))%")
        }

        if !report.muscleBreakdown.isEmpty {
            let topMuscles = report.muscleBreakdown.prefix(3)
                .map { "\($0.muscleGroup.displayName)(\(Int($0.volume))kg)" }
                .joined(separator: ", ")
            lines.append("- Top muscles: \(topMuscles)")
        }

        if !report.highlights.isEmpty {
            lines.append("- Highlights: \(report.highlights.map(\.description).joined(separator: "; "))")
        }

        return lines.joined(separator: "\n")
    }

    /// Returns a locale-appropriate instruction prefix for the prompt.
    private func localeInstruction(periodName: String) -> String {
        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        switch langCode {
        case "ko":
            return "이번 \(periodName == "week" ? "주" : "월")의 운동 데이터를 한국어로 2-3문장으로 요약해주세요. 긍정적이지만 사실에 근거해주세요. 쉬운 표현을 사용해주세요."
        case "ja":
            return "今\(periodName == "week" ? "週" : "月")のワークアウトデータを日本語で2-3文にまとめてください。前向きで事実に基づいた内容にしてください。わかりやすい言葉を使ってください。"
        default:
            return "Summarize this \(periodName)'s workout data in 2-3 concise sentences.\nBe encouraging but factual. Use simple language."
        }
    }
}
