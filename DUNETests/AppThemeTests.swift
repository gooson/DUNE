import Foundation
import Testing
@testable import DUNE

@Suite("AppTheme")
struct AppThemeTests {
    @Test("Raw values are stable (persisted in UserDefaults)")
    func rawValuesStable() {
        #expect(AppTheme.desertWarm.rawValue == "desertWarm")
        #expect(AppTheme.oceanCool.rawValue == "oceanCool")
        #expect(AppTheme.forestGreen.rawValue == "forestGreen")
    }

    @Test("Codable round-trip preserves identity")
    func codableRoundTrip() throws {
        for theme in AppTheme.allCases {
            let data = try JSONEncoder().encode(theme)
            let decoded = try JSONDecoder().decode(AppTheme.self, from: data)
            #expect(decoded == theme)
        }
    }

    @Test("CaseIterable includes all themes")
    func allCases() {
        #expect(AppTheme.allCases.count == 3)
        #expect(AppTheme.allCases.contains(.desertWarm))
        #expect(AppTheme.allCases.contains(.oceanCool))
        #expect(AppTheme.allCases.contains(.forestGreen))
    }

    @Test("Init from unknown rawValue returns nil")
    func unknownRawValue() {
        #expect(AppTheme(rawValue: "neonPunk") == nil)
        #expect(AppTheme(rawValue: "") == nil)
    }
}
