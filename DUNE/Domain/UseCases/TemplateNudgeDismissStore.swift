import Foundation

/// Manages dismiss state for template creation nudge cards.
/// Dismissed nudges are suppressed for 7 days before reappearing.
struct TemplateNudgeDismissStore: Sendable {
    static let shared = TemplateNudgeDismissStore()

    private static let key = "templateNudgeDismissals"
    private static let dismissDurationSeconds: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns true if the recommendation was dismissed within the last 7 days.
    func isDismissed(_ recommendationID: String) -> Bool {
        guard let dismissals = loadDismissals(),
              let dismissDate = dismissals[recommendationID] else {
            return false
        }
        return Date().timeIntervalSince(dismissDate) < Self.dismissDurationSeconds
    }

    /// Records a dismiss for the given recommendation.
    func dismiss(_ recommendationID: String) {
        var dismissals = loadDismissals() ?? [:]
        dismissals[recommendationID] = Date()
        // Prune expired entries to prevent unbounded growth
        let now = Date()
        dismissals = dismissals.filter { now.timeIntervalSince($0.value) < Self.dismissDurationSeconds }
        saveDismissals(dismissals)
    }

    // MARK: - Private

    private func loadDismissals() -> [String: Date]? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode([String: Date].self, from: data)
    }

    private func saveDismissals(_ dismissals: [String: Date]) {
        guard let data = try? JSONEncoder().encode(dismissals) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
