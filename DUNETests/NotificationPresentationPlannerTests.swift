import SwiftUI
import Testing
@testable import DUNE

@Suite("NotificationPresentationPlanner standalone")
struct NotificationPresentationPlannerStandaloneTests {

    @Test("sleepDetail route produces openSleepDetailInWellness plan")
    func sleepDetailRoute() {
        let route = NotificationRoute.sleepDetail
        let plan = NotificationPresentationPlanner.plan(for: route, requestID: 1)
        guard case .openSleepDetailInWellness(let requestID) = plan else {
            Issue.record("Expected openSleepDetailInWellness, got \(String(describing: plan))")
            return
        }
        #expect(requestID == 1)
    }

    @Test("workoutDetail route with valid workoutID produces openWorkoutInActivity plan")
    func workoutDetailRoute() throws {
        let route = try #require(NotificationRoute.workoutDetail(workoutID: "w-123"))
        let plan = NotificationPresentationPlanner.plan(for: route, requestID: 2)
        guard case .openWorkoutInActivity(let workoutID) = plan else {
            Issue.record("Expected openWorkoutInActivity, got \(String(describing: plan))")
            return
        }
        #expect(workoutID == "w-123")
    }

    @Test("workoutDetail route with empty workoutID returns nil")
    func workoutDetailEmptyID() {
        let route = NotificationRoute.workoutDetail(workoutID: "")
        #expect(route == nil)
    }

    @Test("notificationHub route produces openNotificationHub plan")
    func notificationHubRoute() {
        let route = NotificationRoute.notificationHub
        let plan = NotificationPresentationPlanner.plan(for: route, requestID: 4)
        #expect(plan == .openNotificationHub)
    }

    @Test("activityPersonalRecords route produces push plan with personalRecords destination")
    func activityPersonalRecordsRoute() throws {
        let route = NotificationRoute.activityPersonalRecords
        let plan = try #require(NotificationPresentationPlanner.plan(for: route, requestID: 5))
        let path = NotificationPresentationPlanner.rootPath(for: plan)
        #expect(path.count == 1)
        guard case .personalRecords(let requestID) = path.first else {
            Issue.record("Expected personalRecords destination")
            return
        }
        #expect(requestID == 5)
    }
}

@Suite("NotificationPresentationPaths standalone")
struct NotificationPresentationPathsStandaloneTests {

    @Test("setPath clears other tabs")
    func setPathClearsOtherTabs() {
        var paths = NotificationPresentationPaths()
        paths.today = makePath(count: 1)
        paths.train = makePath(count: 2)

        paths.setPath([.personalRecords(requestID: 1)], for: .wellness)

        #expect(paths.today.isEmpty)
        #expect(paths.train.isEmpty)
        #expect(!paths.wellness.isEmpty)
    }

    @Test("clearAll except preserves specified tab")
    func clearAllExceptPreservesTab() {
        var paths = NotificationPresentationPaths()
        paths.today = makePath(count: 1)
        paths.train = makePath(count: 1)
        paths.wellness = makePath(count: 1)

        paths.clearAll(except: .train)

        #expect(paths.today.isEmpty)
        #expect(!paths.train.isEmpty)
        #expect(paths.wellness.isEmpty)
    }

    private func makePath(count: Int) -> NavigationPath {
        var path = NavigationPath()
        for i in 0..<count {
            path.append(NotificationPresentationDestination.personalRecords(requestID: i))
        }
        return path
    }
}

@Suite("NotificationPresentationState reducer")
struct NotificationPresentationStateReducerTests {

    @Test("notificationHub route selects Today, clears paths, and increments hub signal")
    func notificationHubRouteAppliesState() {
        var state = makeState(selectedSection: .train)
        state.paths.today = makePath(count: 1)
        state.paths.train = makePath(count: 2)
        state.paths.wellness = makePath(count: 1)

        state.apply(NotificationNavigationRequest(itemID: "hub-item", route: .notificationHub))

        #expect(state.selectedSection == .today)
        #expect(state.paths.today.isEmpty)
        #expect(state.paths.train.isEmpty)
        #expect(state.paths.wellness.isEmpty)
        #expect(state.paths.life.isEmpty)
        #expect(state.notificationHubSignal == 1)
        #expect(state.notificationRouteSignal == 0)
        #expect(state.notificationPresentationRequestID == 1)
    }

    @Test("workoutDetail route switches to Train and emits route signal")
    func workoutDetailRouteAppliesState() throws {
        var state = makeState(selectedSection: .today)
        state.paths.today = makePath(count: 1)

        let route = try #require(NotificationRoute.workoutDetail(workoutID: "w-123"))
        state.apply(NotificationNavigationRequest(itemID: "workout-item", route: route))

        #expect(state.selectedSection == .train)
        #expect(state.notificationOpenWorkoutID == "w-123")
        #expect(state.paths.today.isEmpty)
        #expect(state.paths.train.isEmpty)
        #expect(state.notificationRouteSignal == 1)
        #expect(state.notificationHubSignal == 0)
        #expect(state.notificationPresentationRequestID == 1)
    }

    @Test("sleepDetail route switches to Wellness and pushes sleep detail")
    func sleepDetailRouteAppliesState() {
        var state = makeState(selectedSection: .life)
        state.paths.life = makePath(count: 1)

        state.apply(NotificationNavigationRequest(itemID: "sleep-item", route: .sleepDetail))

        #expect(state.selectedSection == .wellness)
        #expect(state.paths.today.isEmpty)
        #expect(state.paths.train.isEmpty)
        #expect(!state.paths.wellness.isEmpty)
        #expect(state.paths.life.isEmpty)
        #expect(state.notificationRouteSignal == 0)
        #expect(state.notificationHubSignal == 0)
        #expect(state.notificationPresentationRequestID == 1)
    }

    @Test("activityPersonalRecords route pushes on the current tab and clears other paths")
    func activityPersonalRecordsRouteAppliesState() {
        var state = makeState(selectedSection: .today)
        state.paths.train = makePath(count: 1)
        state.paths.life = makePath(count: 1)

        state.apply(NotificationNavigationRequest(itemID: "pr-item", route: .activityPersonalRecords))

        #expect(state.selectedSection == .today)
        #expect(!state.paths.today.isEmpty)
        #expect(state.paths.train.isEmpty)
        #expect(state.paths.wellness.isEmpty)
        #expect(state.paths.life.isEmpty)
        #expect(state.notificationRouteSignal == 0)
        #expect(state.notificationHubSignal == 0)
        #expect(state.notificationPresentationRequestID == 1)
    }

    private func makeState(selectedSection: AppSection) -> NotificationPresentationState {
        NotificationPresentationState(
            selectedSection: selectedSection,
            notificationOpenWorkoutID: nil,
            paths: NotificationPresentationPaths(),
            notificationPresentationRequestID: 0,
            notificationRouteSignal: 0,
            notificationHubSignal: 0
        )
    }

    private func makePath(count: Int) -> NavigationPath {
        var path = NavigationPath()
        for i in 0..<count {
            path.append(NotificationPresentationDestination.personalRecords(requestID: i))
        }
        return path
    }
}
