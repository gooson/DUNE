import Testing

@testable import DUNE

@Suite("LocationService Place Name Formatting")
@MainActor
struct LocationServiceTests {

    @Test("formats subLocality and locality")
    func subLocalityAndLocality() {
        let result = LocationService.formatPlaceName(subLocality: "Gangnam-gu", locality: "Seoul")
        #expect(result == "Gangnam-gu, Seoul")
    }

    @Test("falls back to locality-only when subLocality is nil")
    func localityOnly() {
        let result = LocationService.formatPlaceName(subLocality: nil, locality: "Seoul")
        #expect(result == "Seoul")
    }

    @Test("returns nil when both subLocality and locality are nil")
    func noLocationInfo() {
        let result = LocationService.formatPlaceName(subLocality: nil, locality: nil)
        #expect(result == nil)
    }

    @Test("formats subLocality-only when locality is nil")
    func subLocalityOnly() {
        let result = LocationService.formatPlaceName(subLocality: "Gangnam-gu", locality: nil)
        #expect(result == "Gangnam-gu")
    }
}
