import Foundation
import Observation

/// Manages morning briefing sheet state and template text generation.
@Observable
@MainActor
final class MorningBriefingViewModel {
    private(set) var sections: BriefingTemplateEngine.Sections?

    private static let lastBriefingDateKey = "lastBriefingDate"

    /// Auto-presentation is reserved for the local morning, once per local day.
    static func shouldShowBriefing(
        now: Date = DashboardClock.now(),
        calendar: Calendar = .autoupdatingCurrent,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard LocalDayPeriod(date: now, calendar: calendar) == .morning else { return false }
        let lastDate = defaults.string(forKey: lastBriefingDateKey)
        let today = todayString(now: now, calendar: calendar)
        return lastDate != today
    }

    /// Record that the briefing was shown today.
    static func markBriefingShown(
        now: Date = DashboardClock.now(),
        calendar: Calendar = .autoupdatingCurrent,
        defaults: UserDefaults = .standard
    ) {
        // A manual visit outside the morning must not consume the next morning's briefing.
        guard LocalDayPeriod(date: now, calendar: calendar) == .morning else { return }
        defaults.set(todayString(now: now, calendar: calendar), forKey: lastBriefingDateKey)
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

    private static func todayString(now: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: now)
    }
}
