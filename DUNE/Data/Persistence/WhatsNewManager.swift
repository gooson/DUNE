import Foundation
import OSLog

/// Shared release catalog for the What's New surface.
/// Loads from per-version JSON files bundled individually from `whats-new/`.
final class WhatsNewManager: Sendable {
    static let shared = WhatsNewManager()

    private let releases: [WhatsNewReleaseData]

    init(bundle: Bundle = .main) {
        guard let catalogURL = bundle.url(forResource: "catalog", withExtension: "json") else {
            AppLogger.data.error("[WhatsNew] catalog.json not found in bundle")
            releases = []
            return
        }

        let decoder = JSONDecoder()
        let catalogIndex: WhatsNewCatalogIndex
        do {
            let data = try Data(contentsOf: catalogURL)
            catalogIndex = try decoder.decode(WhatsNewCatalogIndex.self, from: data)
        } catch {
            AppLogger.data.error("[WhatsNew] Failed to decode catalog.json: \(error)")
            releases = []
            return
        }

        var loaded: [WhatsNewReleaseData] = []
        for entry in catalogIndex.releases {
            guard let versionURL = bundle.url(
                forResource: entry.version,
                withExtension: "json"
            ) else {
                AppLogger.data.warning("[WhatsNew] \(entry.version).json not found, skipping")
                continue
            }

            do {
                let data = try Data(contentsOf: versionURL)
                let detail = try decoder.decode(WhatsNewVersionDetail.self, from: data)
                let release = WhatsNewReleaseData(
                    version: entry.version,
                    introKey: entry.introKey,
                    features: detail.features
                )
                loaded.append(release)
            } catch {
                AppLogger.data.error("[WhatsNew] Failed to decode \(entry.version).json: \(error)")
            }
        }

        releases = loaded
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
