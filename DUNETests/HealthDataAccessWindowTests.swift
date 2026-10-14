import Foundation
import HealthKit
import Testing
@testable import DUNE

@Suite("HealthDataAccessWindow")
struct HealthDataAccessWindowTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private let boundary = Date(timeIntervalSince1970: 1_800_086_400)
    private let hrvIdentifier = HKQuantityType(.heartRateVariabilitySDNN).identifier
    private let rhrIdentifier = HKQuantityType(.restingHeartRate).identifier

    @Test("Limited access is specific to each HealthKit data type")
    func typeSpecificBoundary() {
        let window = HealthDataAccessWindow(limitedStartDates: [hrvIdentifier: boundary])

        #expect(window.limitedStartDate(for: hrvIdentifier) == boundary)
        #expect(window.limitedStartDate(for: rhrIdentifier) == nil)
    }

    @Test("A missing boundary never narrows a point-sample query")
    func absentBoundary() {
        let window = HealthDataAccessWindow()

        #expect(window.pointSampleQueryStart(for: "hrv", intendedStart: start) == start)
    }

    @Test("Point-sample queries start at the later of requested and authorized dates")
    func queryStart() {
        let window = HealthDataAccessWindow(limitedStartDates: ["hrv": boundary])
        let later = boundary.addingTimeInterval(3_600)

        #expect(window.pointSampleQueryStart(for: "hrv", intendedStart: start) == boundary)
        #expect(window.pointSampleQueryStart(for: "hrv", intendedStart: later) == later)
    }

    @Test("Any condition boundary change invalidates visible derived history")
    func changedConditionHistory() {
        let full = HealthDataAccessWindow()
        let limited = HealthDataAccessWindow(limitedStartDates: [hrvIdentifier: start])
        let narrower = HealthDataAccessWindow(limitedStartDates: [hrvIdentifier: boundary])
        let unrelated = HealthDataAccessWindow(limitedStartDates: ["steps": boundary])

        #expect(limited.changesConditionAccess(comparedTo: full, for: [hrvIdentifier, rhrIdentifier]))
        #expect(narrower.changesConditionAccess(comparedTo: limited, for: [hrvIdentifier, rhrIdentifier]))
        #expect(limited.changesConditionAccess(comparedTo: narrower, for: [hrvIdentifier, rhrIdentifier]))
        #expect(full.changesConditionAccess(comparedTo: limited, for: [hrvIdentifier, rhrIdentifier]))
        #expect(!unrelated.changesConditionAccess(comparedTo: full, for: [hrvIdentifier, rhrIdentifier]))
    }

    @Test("A limited boundary survives persistence for cold-launch comparison")
    func persistedWindow() throws {
        let saved = HealthDataAccessWindow(limitedStartDates: [hrvIdentifier: start])
        let restored = try JSONDecoder().decode(
            HealthDataAccessWindow.self,
            from: JSONEncoder().encode(saved)
        )
        let narrowed = HealthDataAccessWindow(limitedStartDates: [hrvIdentifier: boundary])

        #expect(restored == saved)
        #expect(narrowed.changesConditionAccess(comparedTo: restored, for: [hrvIdentifier]))
    }
}
