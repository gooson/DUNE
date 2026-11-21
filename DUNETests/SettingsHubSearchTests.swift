import Foundation
import Testing
@testable import DUNE

@Suite("SettingsHubSearchIndex")
@MainActor
struct SettingsHubSearchTests {
    @Test("Every search result has a stable unique identifier")
    func uniqueIDs() {
        let entries = SettingsHubSearchIndex.entries(includeSimulator: true)
        #expect(Set(entries.map(\.id)).count == entries.count)
        #expect(entries.count >= 49)
        #expect(entries.filter { $0.id.hasPrefix("theme-") }.count == AppTheme.allCases.count)
    }

    @Test("Bedtime names lead to bedtime settings")
    func bedtimeDestinations() {
        let entries = SettingsHubSearchIndex.entries(includeSimulator: false)
        for id in ["bedtime", "bedtime-lead-time", "bedtime-watch", "bedtime-watch-lead-time"] {
            let entry = entries.first { $0.id == id }
            guard let entry else {
                Issue.record("Missing search entry: \(id)")
                continue
            }
            if case .bedtime = entry.route {
                // Expected destination.
            } else {
                Issue.record("\(id) must open bedtime settings")
            }
        }
    }

    @Test("All nine theme names lead to their own previews")
    func themeDestinations() {
        let entries = SettingsHubSearchIndex.entries(includeSimulator: false)
        for theme in AppTheme.allCases {
            let entry = entries.first { $0.id == "theme-\(theme.rawValue)" }
            guard let entry else {
                Issue.record("Missing theme: \(theme.rawValue)")
                continue
            }
            if case .preview(let destination) = entry.route {
                #expect(destination == theme)
            } else {
                Issue.record("\(theme.rawValue) must open theme preview")
            }
        }
    }

    @Test("Korean native labels and English aliases find bedtime controls")
    func koreanAndEnglishBedtimeSearch() throws {
        let koreanURL = try #require(Bundle.main.url(forResource: "ko", withExtension: "lproj"))
        let koreanBundle = try #require(Bundle(url: koreanURL))
        let native = SettingsHubSearchIndex.results(for: "취침", bundle: koreanBundle, includeSimulator: false)
        let english = SettingsHubSearchIndex.results(for: "BEDTIME", bundle: koreanBundle, includeSimulator: false)
        #expect(native.contains { $0.id == "bedtime" })
        #expect(native.contains { $0.id == "bedtime-watch" })
        #expect(english.contains { $0.id == "bedtime" })
        #expect(english.contains { $0.id == "bedtime-watch" })
        #expect(SettingsHubSearchIndex.results(for: "휴식시간", bundle: koreanBundle, includeSimulator: false).contains { $0.id == "rest-time" })
    }

    @Test("Whitespace and accents normalize without changing destinations")
    func normalization() {
        let result = SettingsHubSearchIndex.results(for: "  PATISSERIE   ", includeSimulator: false)
        #expect(result.map(\.id).contains("theme-patisserie"))
        #expect(SettingsHubSearchIndex.results(for: "resttime", includeSimulator: false).contains { $0.id == "rest-time" })
        #expect(SettingsHubSearchIndex.results(for: "  ", includeSimulator: false).isEmpty)
    }

    @Test("Simulator tools are hidden on real devices")
    func simulatorConditional() {
        let realDevice = SettingsHubSearchIndex.entries(includeSimulator: false)
        let simulator = SettingsHubSearchIndex.entries(includeSimulator: true)
        #expect(realDevice.allSatisfy { !$0.id.hasPrefix("mock-") })
        #expect(simulator.filter { $0.id.hasPrefix("mock-") }.count == 4)
    }
}
