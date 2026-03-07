import Foundation

/// Shared release catalog for the What's New surface.
final class WhatsNewManager: Sendable {
    static let shared = WhatsNewManager()

    private let releases: [WhatsNewReleaseData]

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "whats-new", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(WhatsNewCatalog.self, from: data)
        else {
            releases = []
            return
        }
        releases = catalog.releases
    }

    /// Test-only initializer with pre-built releases.
    init(releases: [WhatsNewReleaseData]) {
        self.releases = releases
    }

    func currentAppVersion(bundle: Bundle = .main) -> String {
        bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    func currentBuildNumber(bundle: Bundle = .main) -> String {
        bundle.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    func orderedReleases(preferredVersion: String? = nil) -> [WhatsNewReleaseData] {
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

    func currentRelease(for version: String) -> WhatsNewReleaseData? {
        releases.first { $0.version == version }
    }
}
