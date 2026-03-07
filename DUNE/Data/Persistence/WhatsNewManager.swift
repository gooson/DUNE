import Foundation

/// Shared release catalog for the What's New surface.
final class WhatsNewManager: Sendable {
    static let shared = WhatsNewManager()

    func currentAppVersion(bundle: Bundle = .main) -> String {
        bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    func currentBuildNumber(bundle: Bundle = .main) -> String {
        bundle.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    func orderedReleases(preferredVersion: String? = nil) -> [WhatsNewRelease] {
        let releases = releaseCatalog
        guard let preferredVersion,
              let preferredIndex = releases.firstIndex(where: { $0.version == preferredVersion }) else {
            return releases
        }

        let preferred = releases[preferredIndex]
        let archive = releases.enumerated()
            .filter { $0.offset != preferredIndex }
            .map(\.element)
        return [preferred] + archive
    }

    func currentRelease(for version: String) -> WhatsNewRelease? {
        releaseCatalog.first { $0.version == version }
    }

    private var releaseCatalog: [WhatsNewRelease] {
        [
            WhatsNewRelease(
                version: "0.2.0",
                intro: String(localized: "Start with condition, weather, sleep debt, notifications, widgets, muscle map, training, wellness, habits, themes, and Apple Watch workouts in one flow."),
                features: [
                    .widgets,
                    .conditionScore,
                    .weather,
                    .sleepDebt,
                    .notifications,
                    .muscleMap,
                    .trainingReadiness,
                    .wellness,
                    .habits,
                    .themes,
                    .watchQuickStart
                ]
            )
        ]
    }
}
