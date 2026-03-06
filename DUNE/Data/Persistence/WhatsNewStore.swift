import Foundation

/// Persists the most recent app version that already surfaced the What's New entry point.
final class WhatsNewStore: @unchecked Sendable {
    static let shared = WhatsNewStore()

    private enum Keys {
        static let lastPresentedVersion = (Bundle.main.bundleIdentifier ?? "com.dailve") + ".whatsNew.lastPresentedVersion"
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

    func lastPresentedVersion() -> String? {
        queue.sync {
            defaults.string(forKey: Keys.lastPresentedVersion)
        }
    }

    func shouldPresent(version: String) -> Bool {
        guard !version.isEmpty else { return false }
        return queue.sync {
            defaults.string(forKey: Keys.lastPresentedVersion) != version
        }
    }

    func markPresented(version: String) {
        guard !version.isEmpty else { return }
        queue.sync {
            defaults.set(version, forKey: Keys.lastPresentedVersion)
        }
    }
}
