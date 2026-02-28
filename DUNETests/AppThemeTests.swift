import Foundation
import Testing
@testable import DUNE

@Suite("AppTheme")
struct AppThemeTests {
    @Test("Raw values are stable (persisted in UserDefaults)")
    func rawValuesStable() {
        #expect(AppTheme.desertWarm.rawValue == "desertWarm")
        #expect(AppTheme.oceanCool.rawValue == "oceanCool")
    }

    @Test("Codable round-trip preserves identity")
    func codableRoundTrip() throws {
        for theme in AppTheme.allCases {
            let data = try JSONEncoder().encode(theme)
            let decoded = try JSONDecoder().decode(AppTheme.self, from: data)
            #expect(decoded == theme)
        }
    }

    @Test("CaseIterable includes both themes")
    func allCases() {
        #expect(AppTheme.allCases.count == 2)
        #expect(AppTheme.allCases.contains(.desertWarm))
        #expect(AppTheme.allCases.contains(.oceanCool))
    }

    @Test("Init from unknown rawValue returns nil")
    func unknownRawValue() {
        #expect(AppTheme(rawValue: "neonPunk") == nil)
        #expect(AppTheme(rawValue: "") == nil)
    }
}
