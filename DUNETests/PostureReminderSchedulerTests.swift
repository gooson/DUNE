import Foundation
import Testing
import UserNotifications
@testable import DUNE

@Suite("PostureReminderScheduler")
@MainActor
struct PostureReminderSchedulerTests {
    @Test("Scheduled posture reminder carries an assessment destination")
    func scheduledPayload() async throws {
        let suiteName = "PostureReminderSchedulerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: PostureReminderScheduler.settingsKey)
        let scheduler = RecordingReminderNotificationScheduler()

        await PostureReminderScheduler(
            notificationScheduler: scheduler,
            userDefaults: defaults
        ).refreshSchedule()

        let request = try #require(scheduler.requests.first)
        let payload = NotificationResponsePayload(userInfo: request.content.userInfo)
        #expect(payload.routeKind == NotificationRoute.postureAssessment.destination.rawValue)
        #expect(payload.insightType == HealthInsight.InsightType.postureReminder.rawValue)
    }
}

@Suite("DailyDigestScheduler")
@MainActor
struct DailyDigestSchedulerTests {
    @Test("Scheduled daily digest opens its summary")
    func scheduledPayload() async throws {
        let suiteName = "DailyDigestSchedulerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: DailyDigestScheduler.settingsKey)
        let scheduler = RecordingReminderNotificationScheduler()

        await DailyDigestScheduler(
            notificationScheduler: scheduler,
            userDefaults: defaults
        ).refreshSchedule()

        let request = try #require(scheduler.requests.first)
        let payload = NotificationResponsePayload(userInfo: request.content.userInfo)
        #expect(payload.routeKind == NotificationRoute.dailyDigest.destination.rawValue)
        #expect(payload.insightType == HealthInsight.InsightType.dailyDigest.rawValue)
    }
}

@MainActor
private final class RecordingReminderNotificationScheduler: BedtimeReminderNotificationScheduling {
    var requests: [UNNotificationRequest] = []

    func isAuthorized() async -> Bool { true }

    func add(_ request: UNNotificationRequest) async throws {
        requests.append(request)
    }

    func removePendingReminder(identifier: String) { }
}
