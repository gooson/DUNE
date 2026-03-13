import SwiftUI
import Testing
@testable import DUNE

@Suite("NotificationPresentationPlanner")
struct NotificationPresentationPlannerTests {

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
    func workoutDetailRoute() {
        let route = NotificationRoute.workoutDetail(workoutID: "w-123")
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
        let plan = NotificationPresentationPlanner.plan(for: route, requestID: 3)
        #expect(plan == nil)
    }

    @Test("notificationHub route produces openNotificationHub plan")
    func notificationHubRoute() {
        let route = NotificationRoute.notificationHub
        let plan = NotificationPresentationPlanner.plan(for: route, requestID: 4)
        #expect(plan == .openNotificationHub)
    }

    @Test("activityPersonalRecords route produces push plan with personalRecords destination")
    func activityPersonalRecordsRoute() {
        let route = NotificationRoute.activityPersonalRecords
        let plan = NotificationPresentationPlanner.plan(for: route, requestID: 5)
        let path = NotificationPresentationPlanner.rootPath(for: plan!)
        #expect(path.count == 1)
        guard case .personalRecords(let requestID) = path.first else {
            Issue.record("Expected personalRecords destination")
            return
        }
        #expect(requestID == 5)
    }
}

@Suite("NotificationPresentationPaths")
struct NotificationPresentationPathsTests {

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
