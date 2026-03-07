import Foundation

/// Persists the most recent build that the user already opened from the What's New entry point.
final class WhatsNewStore: @unchecked Sendable {
    static let shared = WhatsNewStore()

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
        queue.sync {
            defaults.set(build, forKey: Keys.lastOpenedBuild)
        }
    }
}
