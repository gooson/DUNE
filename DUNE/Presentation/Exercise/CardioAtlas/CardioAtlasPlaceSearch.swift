import CoreLocation
import MapKit

@MainActor
enum CardioAtlasPlaceSearch {
    private static let initialConsonants = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ".unicodeScalars)
    private static let genericGymQueries: Set<String> = [
        "헬스", "헬스장", "피트니스", "헬스클럽", "gym", "fitness"
    ]
    private static let gymInitialAliases = [
        "ㅎㅅ": "헬스", "ㅎㅅㅈ": "헬스장", "ㅍㅌㄴㅅ": "피트니스", "ㅎㅅㅋㄹ": "헬스클럽"
    ]

    static func normalizedQuery(_ text: String) -> String? {
        let normalized = text.precomposedStringWithCanonicalMapping
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !normalized.isEmpty else { return nil }
        var converted = ""
        var hasInitialConsonant = false
        for scalar in normalized.unicodeScalars {
            switch scalar.value {
            case 0x1100...0x1112:
                converted += String(initialConsonants[Int(scalar.value - 0x1100)])
                hasInitialConsonant = true
            case 0x1100...0x11FF, 0x3130...0x318F, 0xA960...0xA97F, 0xD7B0...0xD7FF:
                guard initialConsonants.contains(scalar) else { return nil }
                converted += String(scalar)
                hasInitialConsonant = true
            default:
                converted += String(scalar)
            }
        }
        guard !hasInitialConsonant || converted.count >= 2 else { return nil }
        return converted
    }

    static func usesInitialConsonants(_ query: String) -> Bool {
        guard let normalized = normalizedQuery(query) else { return false }
        return normalized.unicodeScalars.contains(where: { initialConsonants.contains($0) })
    }

    static func expandedInitialQuery(_ query: String) -> String? {
        guard let normalized = normalizedQuery(query), usesInitialConsonants(normalized) else { return nil }
        return gymInitialAliases[normalized]
    }

    static func referenceCoordinate(
        current: CLLocationCoordinate2D?,
        initialPlace: WorkoutPlace?
    ) -> CLLocationCoordinate2D? {
        if let current, isValid(current) { return current }
        guard let initialPlace else { return nil }
        let coordinate = CLLocationCoordinate2D(
            latitude: initialPlace.latitude,
            longitude: initialPlace.longitude
        )
        return isValid(coordinate) ? coordinate : nil
    }

    static func request(query: String, near coordinate: CLLocationCoordinate2D?) -> MKLocalSearch.Request {
        let request = MKLocalSearch.Request()
        let expanded = expandedInitialQuery(query)
        request.naturalLanguageQuery = expanded ?? query
        if isGenericGymQuery(query) {
            request.resultTypes = .pointOfInterest
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.fitnessCenter])
        } else if expanded != nil {
            // Initials must also find named gyms without a MapKit category.
            request.resultTypes = .pointOfInterest
        } else {
            request.resultTypes = [.pointOfInterest, .address]
        }
        if let coordinate, isValid(coordinate) {
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 20_000,
                longitudinalMeters: 20_000
            )
        }
        return request
    }

    static func nearbyRequest(near coordinate: CLLocationCoordinate2D) -> MKLocalPointsOfInterestRequest {
        MKLocalPointsOfInterestRequest(
            center: coordinate,
            radius: min(10_000, MKLocalPointsOfInterestRequest.maxRadius)
        )
    }

    static func sorted(
        _ items: [MKMapItem],
        near coordinate: CLLocationCoordinate2D?,
        matching query: String? = nil
    ) -> [MKMapItem] {
        let hangulWords = query.flatMap(normalizedQuery).flatMap { normalized -> [String]? in
            guard normalized.unicodeScalars.contains(where: {
                (0xAC00...0xD7A3).contains($0.value) || initialConsonants.contains($0)
            }) else {
                return nil
            }
            return normalized.split(separator: " ").map { foldedForMatch(String($0)) }
        }
        let validItems = items.enumerated().compactMap { index, item -> (index: Int, item: MKMapItem, coordinate: CLLocationCoordinate2D)? in
            let itemCoordinate = item.placemark.coordinate
            guard isValid(itemCoordinate) else { return nil }
            if let hangulWords {
                let nameAndAddress = foldedForMatch([item.name, item.placemark.title]
                    .compactMap { $0 }.joined(separator: " "))
                // A facility category satisfies only that generic word; other
                // words (such as a district) must still match the name/address.
                guard hangulWords.allSatisfy({ word in
                    matches(word, in: nameAndAddress)
                        || (item.pointOfInterestCategory == .fitnessCenter
                            && (isGenericGymQuery(word) || expandedInitialQuery(word) != nil))
                }) else { return nil }
            }
            return (index, item, itemCoordinate)
        }
        guard let coordinate, isValid(coordinate) else { return validItems.map(\.item) }
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        // nearest-first; preserve MapKit order when distances are equal.
        return validItems
            .map { entry in
                let location = CLLocation(latitude: entry.coordinate.latitude, longitude: entry.coordinate.longitude)
                return (index: entry.index, item: entry.item, distance: origin.distance(from: location))
            }
            .sorted { left, right in
                if left.distance == right.distance { return left.index < right.index }
                return left.distance < right.distance
            }
            .map(\.item)
    }

    private static func isValid(_ coordinate: CLLocationCoordinate2D) -> Bool {
        WorkoutRoutePoint.validCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private static func isGenericGymQuery(_ query: String) -> Bool {
        guard let normalized = normalizedQuery(query) else { return false }
        return genericGymQueries.contains(normalized.lowercased())
    }

    private static func foldedForMatch(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "ko_KR"))
            .precomposedStringWithCanonicalMapping
            .filter { !$0.isWhitespace }
    }

    private static func matches(_ word: String, in candidate: String) -> Bool {
        let needle = Array(word.unicodeScalars)
        let haystack = Array(candidate.unicodeScalars)
        guard !needle.isEmpty, needle.count <= haystack.count else { return false }
        for start in 0...(haystack.count - needle.count) {
            let matchesAtStart = needle.indices.allSatisfy { offset in
                let expected = needle[offset]
                let actual = haystack[start + offset]
                guard let initialIndex = initialConsonants.firstIndex(of: expected) else {
                    return expected == actual
                }
                if (0xAC00...0xD7A3).contains(actual.value) {
                    return Int((actual.value - 0xAC00) / 588) == initialIndex
                }
                return expected == actual
            }
            if matchesAtStart { return true }
        }
        return false
    }
}
