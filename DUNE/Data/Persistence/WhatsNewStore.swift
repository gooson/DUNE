import Foundation

/// Persists the most recent build that the user already opened from the What's New entry point.
final class WhatsNewStore: @unchecked Sendable {
    static let shared = WhatsNewStore()
    static let didChangeNotification = Notification.Name("WhatsNewStore.didChange")

    private enum Keys {
        static let lastOpenedBuild = (Bundle.main.bundleIdentifier ?? "com.dailve") + ".whatsNew.lastOpenedBuild"
    }

    private let defaults: UserDefaults
    private let queue: DispatchQueue

    init(
        defaults: UserDefaults = .standard,
        queue: DispatchQueue = DispatchQueue(label: "com.dune.whats-new-store")
    ) {
        self.defaults = defaults
        self.queue = queue
    }

    func lastOpenedBuild() -> String? {
        queue.sync {
            defaults.string(forKey: Keys.lastOpenedBuild)
        }
    }

    func shouldShowBadge(build: String) -> Bool {
        guard !build.isEmpty else { return false }
        return queue.sync {
            defaults.string(forKey: Keys.lastOpenedBuild) != build
        }
    }

    func markOpened(build: String) {
        guard !build.isEmpty else { return }
        let changed = queue.sync {
            guard defaults.string(forKey: Keys.lastOpenedBuild) != build else { return false }
            defaults.set(build, forKey: Keys.lastOpenedBuild)
            return true
        }
        if changed {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }
}

/// The one current release represented in the notification inbox.
struct WhatsNewInboxRelease {
    let release: WhatsNewReleaseData
    let build: String
    let isUnread: Bool

    static func current(
        manager: WhatsNewManager = .shared,
        store: WhatsNewStore = .shared,
        version: String? = nil,
        build: String? = nil
    ) -> Self? {
        let resolvedVersion = version ?? manager.currentAppVersion()
        let resolvedBuild = build ?? manager.currentBuildNumber()
        guard !resolvedBuild.isEmpty,
              let release = manager.currentRelease(for: resolvedVersion) else { return nil }
        return Self(release: release, build: resolvedBuild, isUnread: store.shouldShowBadge(build: resolvedBuild))
    }
}
