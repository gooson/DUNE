import Foundation
import Observation

/// Manages morning briefing sheet state and template text generation.
@Observable
@MainActor
final class MorningBriefingViewModel {
    private(set) var sections: BriefingTemplateEngine.Sections?
    private(set) var isAnimating = false

    private static let lastBriefingDateKey = "lastBriefingDate"

    /// Whether the briefing sheet should be presented today.
    static func shouldShowBriefing() -> Bool {
        let lastDate = UserDefaults.standard.string(forKey: lastBriefingDateKey)
        let today = Self.todayString()
        return lastDate != today
    }

    /// Record that the briefing was shown today.
    static func markBriefingShown() {
        UserDefaults.standard.set(todayString(), forKey: lastBriefingDateKey)
    }

    /// Whether the user has enabled morning briefing in settings.
    static var isEnabled: Bool {
        get { !UserDefaults.standard.bool(forKey: "morningBriefingDisabled") }
        set { UserDefaults.standard.set(!newValue, forKey: "morningBriefingDisabled") }
    }

    func loadSections(from data: MorningBriefingData) {
        sections = BriefingTemplateEngine.generate(from: data)
    }

    func beginAnimation() {
        isAnimating = true
    }

    // MARK: - Private

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
