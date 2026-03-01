import Testing

@testable import DUNE

// LocationService tests previously covered formatPlaceName (removed in iOS 26 migration).
// reverseGeocode() depends on MKReverseGeocodingRequest (not unit-testable without network).
// Placeholder suite retained for future testable helpers.
@Suite("LocationService")
struct LocationServiceTests {
}
