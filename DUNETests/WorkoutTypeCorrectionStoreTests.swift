import XCTest
@testable import DUNE

final class WorkoutTypeCorrectionStoreTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var store: WorkoutTypeCorrectionStore!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "WorkoutTypeCorrectionStoreTests")
        userDefaults.removePersistentDomain(forName: "WorkoutTypeCorrectionStoreTests")
        store = WorkoutTypeCorrectionStore(userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "WorkoutTypeCorrectionStoreTests")
        userDefaults = nil
        store = nil
        super.tearDown()
    }

    func testSetAndGetCorrectedTitle() {
        store.setCorrectedTitle("체스트 프레스", for: "hk-1")

        XCTAssertEqual(store.correctedTitle(for: "hk-1"), "체스트 프레스")
    }

    func testSetCorrectedTitleTrimsWhitespace() {
        store.setCorrectedTitle("  Bench Press  ", for: "hk-2")

        XCTAssertEqual(store.correctedTitle(for: "hk-2"), "Bench Press")
    }

    func testSetCorrectedTitleRemovesWhenEmpty() {
        store.setCorrectedTitle("Bench Press", for: "hk-3")
        store.setCorrectedTitle("   ", for: "hk-3")

        XCTAssertNil(store.correctedTitle(for: "hk-3"))
    }

    func testSetCorrectedTitleRemovesWhenNil() {
        store.setCorrectedTitle("Bench Press", for: "hk-4")
        store.setCorrectedTitle(nil, for: "hk-4")

        XCTAssertNil(store.correctedTitle(for: "hk-4"))
    }
}
