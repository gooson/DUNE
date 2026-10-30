import Foundation
import Testing
@testable import DUNE

@Suite("HealthQuerySearchIndex")
@MainActor
struct HealthQuerySearchIndexTests {
    @Test("Only bounded app-authored memo snapshots are indexed")
    func boundedSnapshot() {
        let records = [
            HealthQueryWorkoutSnapshot(id: "app", name: "Run", date: .now, memo: String(repeating: "x", count: 600)),
            HealthQueryWorkoutSnapshot(id: "hk", name: "Health", date: .now, memo: "Private", source: .healthKit),
            HealthQueryWorkoutSnapshot(id: "empty", name: "Empty", date: .now),
            HealthQueryWorkoutSnapshot(id: "app", name: "Duplicate", date: .now, memo: "Duplicate")
        ]
        let items = HealthQuerySearchIndex.items(records)
        #expect(items.count == 1)
        #expect(items.first?.uniqueIdentifier == "app")
        #expect(items.first?.attributeSet.contentDescription?.count == 500)
    }
}
