import CoreLocation
import Contacts
import Foundation
import MapKit
import Testing
@testable import DUNE

@Suite("CardioAtlasPlaceSearch")
@MainActor
struct CardioAtlasPlaceSearchTests {
    @Test("Single initials and loose vowels wait while complete syllables can search")
    func unfinishedHangulQuery() {
        for fragment in ["ㅎ", "ᄒ", "ᅦ", "ᆯ", "\u{A960}", "\u{D7B0}", "  \n  "] {
            #expect(CardioAtlasPlaceSearch.normalizedQuery(fragment) == nil)
        }
        #expect(CardioAtlasPlaceSearch.normalizedQuery("ㅏㅣ") == nil)
        #expect(CardioAtlasPlaceSearch.normalizedQuery("헬") == "헬")
        #expect(CardioAtlasPlaceSearch.normalizedQuery("헬스") == "헬스")
    }

    @Test("Query normalization composes syllables and collapses whitespace")
    func normalizedQuery() {
        #expect(CardioAtlasPlaceSearch.normalizedQuery("  헬스  \n  장  ") == "헬스 장")
        #expect(CardioAtlasPlaceSearch.normalizedQuery("  Atlas\t Gym  ") == "Atlas Gym")
        #expect(CardioAtlasPlaceSearch.normalizedQuery("  ᄒᄉ  ") == "ㅎㅅ")
        #expect(CardioAtlasPlaceSearch.normalizedQuery("헬ᄉ") == "헬ㅅ")
    }

    @Test("Initial consonant detection and known gym expansions")
    func initialConsonantQueries() {
        #expect(CardioAtlasPlaceSearch.usesInitialConsonants("ㅎㅅ"))
        #expect(CardioAtlasPlaceSearch.usesInitialConsonants("헬ᄉ"))
        #expect(!CardioAtlasPlaceSearch.usesInitialConsonants("헬스"))
        #expect(!CardioAtlasPlaceSearch.usesInitialConsonants("ㅎ"))
        #expect(CardioAtlasPlaceSearch.expandedInitialQuery("ㅎㅅ") == "헬스")
        #expect(CardioAtlasPlaceSearch.expandedInitialQuery("ᄑᄐᄂᄉ") == "피트니스")
        #expect(CardioAtlasPlaceSearch.expandedInitialQuery("ㅎㅅㅈ") == "헬스장")
        #expect(CardioAtlasPlaceSearch.expandedInitialQuery("ㅅㅇ") == nil)
        #expect(CardioAtlasPlaceSearch.expandedInitialQuery("헬ㅅ") == nil)
    }

    @Test("Current coordinate takes precedence over the saved place")
    func currentLocationPreferred() throws {
        let current = CLLocationCoordinate2D(latitude: 37.5, longitude: 127)
        let place = try #require(WorkoutPlace(latitude: 35, longitude: 129, name: "Saved", source: .manual))

        let result = CardioAtlasPlaceSearch.referenceCoordinate(current: current, initialPlace: place)

        #expect(result?.latitude == current.latitude)
        #expect(result?.longitude == current.longitude)
    }

    @Test("Invalid or missing current coordinate falls back to the saved place")
    func savedPlaceFallback() throws {
        let place = try #require(WorkoutPlace(latitude: 35, longitude: 129, name: "Saved", source: .manual))
        let invalid = CLLocationCoordinate2D(latitude: .nan, longitude: 127)

        let currentCoordinates: [CLLocationCoordinate2D?] = [nil, invalid]
        for current in currentCoordinates {
            let result = CardioAtlasPlaceSearch.referenceCoordinate(current: current, initialPlace: place)
            #expect(result?.latitude == place.latitude)
            #expect(result?.longitude == place.longitude)
        }
    }

    @Test("No valid current or saved coordinate yields no reference")
    func noReference() throws {
        let invalidPlace = try JSONDecoder().decode(
            WorkoutPlace.self,
            from: Data(#"{"latitude":91,"longitude":127,"name":"Invalid","source":"manual"}"#.utf8)
        )
        #expect(CardioAtlasPlaceSearch.referenceCoordinate(current: nil, initialPlace: nil) == nil)
        #expect(CardioAtlasPlaceSearch.referenceCoordinate(
            current: CLLocationCoordinate2D(latitude: .infinity, longitude: 127),
            initialPlace: invalidPlace
        ) == nil)
    }

    @Test("Request searches points of interest and addresses near the reference")
    func requestConfiguration() {
        let coordinate = CLLocationCoordinate2D(latitude: 37.5, longitude: 127)

        let request = CardioAtlasPlaceSearch.request(query: "track", near: coordinate)

        #expect(request.naturalLanguageQuery == "track")
        #expect(request.resultTypes.contains(.pointOfInterest))
        #expect(request.resultTypes.contains(.address))
        #expect(request.region.center.latitude == coordinate.latitude)
        #expect(request.region.center.longitude == coordinate.longitude)
        let north = CLLocation(latitude: coordinate.latitude + request.region.span.latitudeDelta / 2, longitude: coordinate.longitude)
        let south = CLLocation(latitude: coordinate.latitude - request.region.span.latitudeDelta / 2, longitude: coordinate.longitude)
        #expect(abs(north.distance(from: south) - 20_000) < 1_000)
    }

    @Test("Exact generic gym searches request fitness center points of interest")
    func genericGymRequest() {
        for keyword in ["헬스", "헬스장", "피트니스", "헬스클럽", "gym", "FITNESS"] {
            let request = CardioAtlasPlaceSearch.request(query: keyword, near: nil)
            #expect(request.resultTypes == .pointOfInterest)
            #expect(request.pointOfInterestFilter?.includes(.fitnessCenter) == true)
            #expect(request.pointOfInterestFilter?.includes(.hotel) == false)
        }
    }

    @Test("Named places and address searches retain the broad request")
    func namedAndAddressRequest() {
        for query in ["헬스플러스", "서울 강남구 테헤란로 1", "Atlas Gym"] {
            let request = CardioAtlasPlaceSearch.request(query: query, near: nil)
            #expect(request.resultTypes.contains(.pointOfInterest))
            #expect(request.resultTypes.contains(.address))
            #expect(request.pointOfInterestFilter == nil)
        }
    }

    @Test("Nearby initial search uses the supported radius without a category restriction")
    func nearbyInitialRequest() {
        let coordinate = CLLocationCoordinate2D(latitude: 37.5, longitude: 127)

        let request = CardioAtlasPlaceSearch.nearbyRequest(near: coordinate)

        #expect(request.coordinate.latitude == coordinate.latitude)
        #expect(request.coordinate.longitude == coordinate.longitude)
        #expect(request.radius == min(10_000, MKLocalPointsOfInterestRequest.maxRadius))
        #expect(request.pointOfInterestFilter == nil)
    }

    @Test("Expanded gym initials can find named places without a fitness category")
    func initialAliasIncludesUncategorizedPlaces() {
        let request = CardioAtlasPlaceSearch.request(query: "ㅎㅅ", near: nil)
        #expect(request.naturalLanguageQuery == "헬스")
        #expect(request.resultTypes == .pointOfInterest)
        #expect(request.pointOfInterestFilter == nil)
    }

    @Test("Nearest valid results come first and equal distances keep MapKit order")
    func distanceOrderAndStableTies() {
        let origin = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let far = item("far", latitude: 0, longitude: 2)
        let tieFirst = item("tie-first", latitude: 1, longitude: 0)
        let near = item("near", latitude: 0, longitude: 0.1)
        let tieSecond = item("tie-second", latitude: 1, longitude: 0)

        let result = CardioAtlasPlaceSearch.sorted([far, tieFirst, near, tieSecond], near: origin)

        #expect(result.map(\.name) == ["near", "tie-first", "tie-second", "far"])
    }

    @Test("Invalid candidates are removed, including without a reference")
    func invalidCandidates() {
        let first = item("first", latitude: 0, longitude: 2)
        let invalid = item("invalid", latitude: 91, longitude: 0)
        let second = item("second", latitude: 0, longitude: 1)
        let candidates = [first, invalid, second]

        #expect(CardioAtlasPlaceSearch.sorted(candidates, near: CLLocationCoordinate2D(latitude: 0, longitude: 0))
            .map(\.name) == ["second", "first"])
        #expect(CardioAtlasPlaceSearch.sorted(candidates, near: nil).map(\.name) == ["first", "second"])
        #expect(CardioAtlasPlaceSearch.sorted(candidates, near: CLLocationCoordinate2D(latitude: .nan, longitude: 0))
            .map(\.name) == ["first", "second"])
    }

    @Test("Korean prefix searches keep relevant names and addresses while excluding foreign fuzzy matches")
    func hangulRelevance() {
        let gym = item("헬스플러스", latitude: 0, longitude: 1)
        let addressMatch = addressItem("Other", street: "헬스 거리", latitude: 0, longitude: 2)
        let hotel = item("Danubius Hotel Helia", latitude: 0, longitude: 0.1)

        let result = CardioAtlasPlaceSearch.sorted([hotel, gym, addressMatch], near: nil, matching: "헬")

        #expect(result.map(\.name) == ["헬스플러스", "Other"])
        #expect(CardioAtlasPlaceSearch.sorted([hotel], near: nil, matching: "헬스").isEmpty)
    }

    @Test("Generic Korean gym searches accept categorized fitness centers without a literal name match")
    func gymCategoryRelevance() {
        let gym = item("Neighborhood Fitness", latitude: 0, longitude: 1)
        gym.pointOfInterestCategory = .fitnessCenter
        let hotel = item("Danubius Hotel Helia", latitude: 0, longitude: 0.1)
        hotel.pointOfInterestCategory = .hotel

        let result = CardioAtlasPlaceSearch.sorted([hotel, gym], near: nil, matching: "헬스")

        #expect(result.map(\.name) == ["Neighborhood Fitness"])
        #expect(CardioAtlasPlaceSearch.sorted([hotel, gym], near: nil, matching: "ㅎㅅ").map(\.name)
            == ["Neighborhood Fitness"])
        #expect(CardioAtlasPlaceSearch.sorted([hotel, gym], near: nil, matching: "gym").count == 2)
    }

    @Test("All Korean query words must match, with spaces ignored inside names")
    func multiwordHangulRelevance() {
        let match = item("서울헬스플러스", latitude: 0, longitude: 1)
        let unrelated = item("서울도서관", latitude: 0, longitude: 0.1)

        let result = CardioAtlasPlaceSearch.sorted([unrelated, match], near: nil, matching: "서울 헬스")

        #expect(result.map(\.name) == ["서울헬스플러스"])
    }

    @Test("Initials and mixed syllables match Hangul syllable beginnings")
    func initialConsonantRelevance() {
        let gym = item("헬스플러스", latitude: 0, longitude: 1)
        let hotel = item("Danubius Hotel Helia", latitude: 0, longitude: 0.1)

        #expect(CardioAtlasPlaceSearch.sorted([hotel, gym], near: nil, matching: "ㅎㅅ").map(\.name)
            == ["헬스플러스"])
        #expect(CardioAtlasPlaceSearch.sorted([hotel, gym], near: nil, matching: "헬ㅅ").map(\.name)
            == ["헬스플러스"])
        #expect(CardioAtlasPlaceSearch.sorted([hotel], near: nil, matching: "ㅎㅅ").isEmpty)
    }

    @Test("Generic facility words match a category while district words remain required",
          arguments: ["강남 헬스", "강남 헬스장", "강남 gym", "강남 ㅎㅅ"])
    func districtAndGymCategory(query: String) {
        let gym = addressItem("Gold Fitness", street: "강남구 테헤란로", latitude: 37.5, longitude: 127)
        gym.pointOfInterestCategory = .fitnessCenter
        let otherDistrict = addressItem("Gold Fitness", street: "서초구 서초대로", latitude: 37.5, longitude: 127)
        otherDistrict.pointOfInterestCategory = .fitnessCenter
        let library = addressItem("도서관", street: "강남구 테헤란로", latitude: 37.5, longitude: 127)

        let result = CardioAtlasPlaceSearch.sorted([otherDistrict, library, gym], near: nil, matching: query)

        #expect(result.count == 1)
        #expect(result.first === gym)
    }

    @Test("Multiword literal names still work without a fitness classification")
    func districtAndUncategorizedGym() {
        let named = addressItem("헬스플러스", street: "강남구 테헤란로", latitude: 37.5, longitude: 127)
        let unrelated = addressItem("헬스플러스", street: "서초구 서초대로", latitude: 37.5, longitude: 127)
        #expect(CardioAtlasPlaceSearch.sorted([unrelated, named], near: nil, matching: "강남 헬스")
            .first === named)
    }

    @Test("Initial consonants work across query words and in addresses")
    func multiwordInitialRelevance() {
        let named = item("서울헬스플러스", latitude: 0, longitude: 1)
        let addressed = addressItem("Other", street: "서울 헬스 거리", latitude: 0, longitude: 2)
        let unrelated = item("서울도서관", latitude: 0, longitude: 0.1)

        let result = CardioAtlasPlaceSearch.sorted(
            [unrelated, named, addressed], near: nil, matching: "서울 ㅎㅅ"
        )

        #expect(result.map(\.name) == ["서울헬스플러스", "Other"])
    }

    @Test("Empty input stays empty")
    func emptyResults() {
        #expect(CardioAtlasPlaceSearch.sorted([], near: nil).isEmpty)
    }

    private func item(_ name: String, latitude: Double, longitude: Double) -> MKMapItem {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        return item
    }

    private func addressItem(_ name: String, street: String, latitude: Double, longitude: Double) -> MKMapItem {
        let address = CNMutablePostalAddress()
        address.street = street
        address.city = "서울"
        address.country = "대한민국"
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate, postalAddress: address))
        item.name = name
        return item
    }
}
