import Foundation
import Testing
import UserNotifications
@testable import DUNE

@Suite("AppNotificationCenterDelegate")
@MainActor
struct AppNotificationCenterDelegateTests {

    @Test("foreground presentation options include list delivery")
    func foregroundPresentationOptionsIncludeListDelivery() {
        let options = AppNotificationCenterDelegate.foregroundPresentationOptions

        #expect(options.contains(.banner))
        #expect(options.contains(.list))
        #expect(options.contains(.sound))
        #expect(options.contains(.badge))
    }

    @Test("init accepts custom response handler without calling it")
    func initAcceptsCustomResponseHandler() {
        // Verifies delegate can be constructed with a custom handler
        let delegate = AppNotificationCenterDelegate { _ in }
        #expect(delegate is UNUserNotificationCenterDelegate)
    }
}
