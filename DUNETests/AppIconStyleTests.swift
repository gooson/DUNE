import Foundation
import Testing
import UIKit
@testable import DUNE

@Suite("AppIconStyle")
struct AppIconStyleTests {
    @Test("Approved silhouettes and default remain stable")
    func approvedStyles() {
        #expect(AppIconStyle.allCases.map(\.sourceConceptNumber) == [82, 71, 87])
        #expect(AppIconStyle.defaultStyle == .interleave)
        #expect(AppIconStyle(rawValue: "interleave") == .interleave)
        #expect(AppIconStyle(rawValue: "ocean") == .ocean)
        #expect(AppIconStyle(rawValue: "flow") == .flow)
    }

    @Test("Every style and theme resolves a bundled preview and declared system icon")
    @MainActor
    func completeAssetAndBundleContract() throws {
        let icons = try #require(Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any])
        let alternates = try #require(icons["CFBundleAlternateIcons"] as? [String: Any])
        var names = Set<String>()
        for style in AppIconStyle.allCases {
            for theme in AppTheme.allCases {
                #expect(UIImage(named: style.previewAssetName(for: theme)) != nil)
                if let name = style.alternateIconName(for: theme) {
                    #expect(alternates[name] != nil, "Missing alternate icon \(name)")
                    names.insert(name)
                } else {
                    #expect(style == .interleave && theme == .desertWarm)
                }
            }
        }
        #expect(names.count == 26)
    }

    @Test("Default theme uses P04 while every other theme owns its palette")
    func paletteMapping() {
        #expect(AppTheme.desertWarm.appIconPaletteName == String(localized: "Coral × Sand"))
        #expect(AppTheme.oceanCool.appIconPaletteName == String(localized: "Mint × Periwinkle"))
        #expect(AppTheme.forestGreen.appIconPaletteName == String(localized: "Sage × Cream"))
        #expect(AppTheme.patisserie.appIconPaletteName == String(localized: "Rose × Cream"))
        #expect(Set(AppTheme.allCases.map(\.appIconPaletteName)).count == 9)
    }

    @Test("Persisted icon choice survives defaults round trip")
    func persistence() throws {
        let suite = "AppIconStyleTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(AppIconStyle.flow.rawValue, forKey: AppIconStyle.storageKey)
        #expect(AppIconStyle(rawValue: defaults.string(forKey: AppIconStyle.storageKey) ?? "") == .flow)
    }
}
