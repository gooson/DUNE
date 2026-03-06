import Foundation

/// Shared catalog + route bridge for the What's New surface.
final class WhatsNewManager: @unchecked Sendable {
    static let shared = WhatsNewManager()

    static let routeRequestedNotification = Notification.Name("WhatsNewManager.routeRequested")

    private let queue = DispatchQueue(label: "com.dune.whats-new-manager")
    private var pendingDestination: WhatsNewDestination?

    func currentAppVersion(bundle: Bundle = .main) -> String {
        bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
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

    func requestNavigation(_ destination: WhatsNewDestination) {
        queue.sync {
            pendingDestination = destination
        }
        Task { @MainActor in
            NotificationCenter.default.post(name: Self.routeRequestedNotification, object: destination)
        }
    }

    func consumePendingNavigationDestination() -> WhatsNewDestination? {
        queue.sync {
            defer { pendingDestination = nil }
            return pendingDestination
        }
    }

    func clearPendingNavigationDestination(ifMatching destination: WhatsNewDestination) {
        queue.sync {
            if pendingDestination == destination {
                pendingDestination = nil
            }
        }
    }

    static func destination(from notification: Notification) -> WhatsNewDestination? {
        notification.object as? WhatsNewDestination
    }

    private var releaseCatalog: [WhatsNewRelease] {
        [
            WhatsNewRelease(
                version: "0.2.0",
                intro: String(localized: "Start with condition, notifications, training, wellness, habits, and Apple Watch workouts in one flow."),
                features: [
                    .conditionScore,
                    .notifications,
                    .trainingReadiness,
                    .wellness,
                    .habits,
                    .watchQuickStart
                ]
            )
        ]
    }
}
