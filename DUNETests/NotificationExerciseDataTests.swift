import Foundation
import Testing
@testable import DUNE

// MARK: - NotificationRoute Validation

@Suite("NotificationRoute – exercise data validation")
struct NotificationRouteValidationTests {

    @Test("workoutDetail factory returns route for valid UUID")
    func validWorkoutID() {
        let id = UUID().uuidString
        let route = NotificationRoute.workoutDetail(workoutID: id)
        #expect(route != nil)
        #expect(route?.destination == .workoutDetail)
        #expect(route?.workoutID == id)
    }

    @Test("workoutDetail factory returns nil for empty string")
    func emptyWorkoutID() {
        let route = NotificationRoute.workoutDetail(workoutID: "")
        #expect(route == nil)
    }

    @Test("workoutDetail Codable round trip preserves workoutID")
    func codableRoundTrip() throws {
        let id = "ABCD-1234-EF56"
        let route = try #require(NotificationRoute.workoutDetail(workoutID: id))
        let data = try JSONEncoder().encode(route)
        let decoded = try JSONDecoder().decode(NotificationRoute.self, from: data)
        #expect(decoded == route)
        #expect(decoded.workoutID == id)
    }

    @Test("workoutDetail Hashable equality")
    func hashableEquality() throws {
        let id = "same-id"
        let a = try #require(NotificationRoute.workoutDetail(workoutID: id))
        let b = try #require(NotificationRoute.workoutDetail(workoutID: id))
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("workoutDetail inequality for different IDs")
    func hashableInequality() throws {
        let a = try #require(NotificationRoute.workoutDetail(workoutID: "id-1"))
        let b = try #require(NotificationRoute.workoutDetail(workoutID: "id-2"))
        #expect(a != b)
    }
}

// MARK: - UserInfo Round Trip

@Suite("NotificationInboxManager – exercise data userInfo round trip")
struct NotificationUserInfoRoundTripTests {

    @Test("valid workout route survives encode → decode via userInfo")
    func validRoundTrip() {
        let manager = makeManager()
        let insight = makeInsight(workoutID: "workout-abc-123")
        let item = manager.recordSentInsight(insight)

        let userInfo = manager.notificationUserInfo(for: item)
        // Verify all expected keys present
        #expect(userInfo["notificationItemID"] as? String == item.id)
        #expect(userInfo["notificationRouteKind"] as? String == "workoutDetail")
        #expect(userInfo["notificationWorkoutID"] as? String == "workout-abc-123")

        // Simulate notification tap: feed userInfo back through parseRoute
        let parsedRoute = parseRouteFromUserInfo(manager: manager, userInfo: userInfo)
        #expect(parsedRoute != nil)
        #expect(parsedRoute?.destination == .workoutDetail)
        #expect(parsedRoute?.workoutID == "workout-abc-123")
    }

    @Test("insight without route produces userInfo with itemID only")
    func noRouteInsight() {
        let manager = makeManager()
        let insight = HealthInsight(
            type: .stepGoal,
            title: "10K Steps",
            body: "Reached goal",
            severity: .celebration
        )
        let item = manager.recordSentInsight(insight)
        let userInfo = manager.notificationUserInfo(for: item)

        #expect(userInfo["notificationItemID"] as? String == item.id)
        #expect(userInfo["notificationRouteKind"] == nil)
        #expect(userInfo["notificationWorkoutID"] == nil)

        let parsedRoute = parseRouteFromUserInfo(manager: manager, userInfo: userInfo)
        #expect(parsedRoute == nil)
    }

    @Test("corrupted userInfo with missing routeKind returns nil route")
    func missingRouteKind() {
        let manager = makeManager()
        let userInfo: [AnyHashable: Any] = [
            "notificationItemID": "item-1",
            "notificationWorkoutID": "workout-123"
        ]
        let parsedRoute = parseRouteFromUserInfo(manager: manager, userInfo: userInfo)
        #expect(parsedRoute == nil)
    }

    @Test("corrupted userInfo with missing workoutID returns nil route")
    func missingWorkoutID() {
        let manager = makeManager()
        let userInfo: [AnyHashable: Any] = [
            "notificationItemID": "item-1",
            "notificationRouteKind": "workoutDetail"
        ]
        let parsedRoute = parseRouteFromUserInfo(manager: manager, userInfo: userInfo)
        #expect(parsedRoute == nil)
    }

    @Test("corrupted userInfo with empty workoutID returns nil route")
    func emptyWorkoutID() {
        let manager = makeManager()
        let userInfo: [AnyHashable: Any] = [
            "notificationItemID": "item-1",
            "notificationRouteKind": "workoutDetail",
            "notificationWorkoutID": ""
        ]
        let parsedRoute = parseRouteFromUserInfo(manager: manager, userInfo: userInfo)
        #expect(parsedRoute == nil)
    }

    @Test("corrupted userInfo with non-string workoutID returns nil route")
    func nonStringWorkoutID() {
        let manager = makeManager()
        let userInfo: [AnyHashable: Any] = [
            "notificationItemID": "item-1",
            "notificationRouteKind": "workoutDetail",
            "notificationWorkoutID": 12345
        ]
        let parsedRoute = parseRouteFromUserInfo(manager: manager, userInfo: userInfo)
        #expect(parsedRoute == nil)
    }

    @Test("unknown routeKind returns nil route")
    func unknownRouteKind() {
        let manager = makeManager()
        let userInfo: [AnyHashable: Any] = [
            "notificationItemID": "item-1",
            "notificationRouteKind": "unknownDestination",
            "notificationWorkoutID": "workout-123"
        ]
        let parsedRoute = parseRouteFromUserInfo(manager: manager, userInfo: userInfo)
        #expect(parsedRoute == nil)
    }
}

// MARK: - Inbox Store Codable Preservation

@Suite("NotificationInboxStore – exercise route Codable preservation")
struct NotificationInboxStoreRouteTests {

    @Test("workout route survives store persist → reload cycle")
    func routePreservation() {
        let store = makeStore()
        let insight = makeInsight(workoutID: "persist-test-id")
        let original = store.append(insight: insight)

        let loaded = store.items()
        let found = loaded.first { $0.id == original.id }
        #expect(found != nil)
        #expect(found?.route?.destination == .workoutDetail)
        #expect(found?.route?.workoutID == "persist-test-id")
    }

    @Test("nil route is preserved through store cycle")
    func nilRoutePreservation() {
        let store = makeStore()
        let insight = HealthInsight(
            type: .hrvAnomaly,
            title: "HRV Alert",
            body: "Low",
            severity: .attention
        )
        let original = store.append(insight: insight)

        let loaded = store.items()
        let found = loaded.first { $0.id == original.id }
        #expect(found != nil)
        #expect(found?.route == nil)
    }

    private func makeStore() -> NotificationInboxStore {
        let suiteName = "NotificationExerciseDataTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return NotificationInboxStore(defaults: defaults)
    }
}

// MARK: - handleNotificationResponse Branch Coverage

@Suite("NotificationInboxManager – handleNotificationResponse branches")
struct HandleNotificationResponseTests {

    @Test("valid userInfo with known itemID triggers navigation via open path")
    func validItemIDPath() async {
        let manager = makeManager()
        let insight = makeInsight(workoutID: "nav-test-id")
        let item = manager.recordSentInsight(insight)

        let userInfo = manager.notificationUserInfo(for: item)
        manager.handleNotificationResponse(userInfo: userInfo)

        // Wait briefly for MainActor post
        try? await Task.sleep(nanoseconds: 50_000_000)

        let pending = manager.consumePendingNavigationRequest()
        #expect(pending != nil)
        #expect(pending?.route.workoutID == "nav-test-id")
        #expect(pending?.itemID == item.id)
    }

    @Test("valid userInfo with unknown itemID falls through to parseRoute path")
    func unknownItemIDFallthrough() async {
        let manager = makeManager()
        let userInfo: [AnyHashable: Any] = [
            "notificationItemID": "non-existent-item",
            "notificationRouteKind": "workoutDetail",
            "notificationWorkoutID": "fallthrough-workout"
        ]
        manager.handleNotificationResponse(userInfo: userInfo)

        try? await Task.sleep(nanoseconds: 50_000_000)

        let pending = manager.consumePendingNavigationRequest()
        #expect(pending != nil)
        #expect(pending?.route.workoutID == "fallthrough-workout")
    }

    @Test("userInfo without itemID but with valid route creates navigation")
    func noItemIDWithRoute() async {
        let manager = makeManager()
        let userInfo: [AnyHashable: Any] = [
            "notificationRouteKind": "workoutDetail",
            "notificationWorkoutID": "orphan-workout"
        ]
        manager.handleNotificationResponse(userInfo: userInfo)

        try? await Task.sleep(nanoseconds: 50_000_000)

        let pending = manager.consumePendingNavigationRequest()
        #expect(pending != nil)
        #expect(pending?.route.workoutID == "orphan-workout")
    }

    @Test("completely empty userInfo produces no navigation request")
    func emptyUserInfo() async {
        let manager = makeManager()
        manager.handleNotificationResponse(userInfo: [:])

        try? await Task.sleep(nanoseconds: 50_000_000)

        let pending = manager.consumePendingNavigationRequest()
        #expect(pending == nil)
    }

    @Test("userInfo with itemID but no route marks read without navigation")
    func itemIDOnlyNoRoute() async {
        let manager = makeManager()
        let insight = HealthInsight(
            type: .stepGoal,
            title: "Steps",
            body: "10K",
            severity: .celebration
        )
        let item = manager.recordSentInsight(insight)

        let userInfo: [AnyHashable: Any] = [
            "notificationItemID": item.id
        ]
        manager.handleNotificationResponse(userInfo: userInfo)

        try? await Task.sleep(nanoseconds: 50_000_000)

        // Item should be marked read
        let items = manager.items()
        let found = items.first { $0.id == item.id }
        #expect(found?.isRead == true)

        // No pending navigation (no route)
        let pending = manager.consumePendingNavigationRequest()
        #expect(pending == nil)
    }
}

// MARK: - Helpers

private func makeManager() -> NotificationInboxManager {
    let suiteName = "NotificationExerciseDataTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    defaults.removePersistentDomain(forName: suiteName)
    let store = NotificationInboxStore(defaults: defaults)
    return NotificationInboxManager(store: store, badgeUpdater: { _ in })
}

private func makeInsight(workoutID: String) -> HealthInsight {
    HealthInsight(
        type: .workoutPR,
        title: "New PR",
        body: "You set a record",
        severity: .celebration,
        date: Date(),
        route: .workoutDetail(workoutID: workoutID)
    )
}

/// Exercises `parseRoute` indirectly via `handleNotificationResponse` + `consumePendingNavigationRequest`.
/// When there's no matching inbox item, the manager falls through to `parseRoute`.
private func parseRouteFromUserInfo(
    manager: NotificationInboxManager,
    userInfo: [AnyHashable: Any]
) -> NotificationRoute? {
    // handleNotificationResponse internally calls parseRoute when itemID lookup fails.
    // We construct userInfo with a non-existent itemID to force the parseRoute path.
    var testInfo = userInfo
    testInfo["notificationItemID"] = "force-parse-route-\(UUID().uuidString)"
    manager.handleNotificationResponse(userInfo: testInfo)

    // parseRoute result is captured in pendingNavigationRequest
    return manager.consumePendingNavigationRequest()?.route
}
