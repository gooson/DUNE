import Foundation
import Observation

/// Manages morning briefing sheet state and template text generation.
@Observable
@MainActor
final class MorningBriefingViewModel {
    private(set) var sections: BriefingTemplateEngine.Sections?

    private static let lastBriefingDateKey = "lastBriefingDate"

    private enum Cache {
        static let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }()
    }

    /// Whether the briefing sheet should be presented today.
    static func shouldShowBriefing() -> Bool {
        let lastDate = UserDefaults.standard.string(forKey: lastBriefingDateKey)
        let today = todayString()
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

    // MARK: - Private

    private static func todayString() -> String {
        Cache.dateFormatter.string(from: Date())
    }
}
