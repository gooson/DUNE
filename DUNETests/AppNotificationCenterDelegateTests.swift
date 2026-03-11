import Foundation
import Testing
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

    @Test("forwardNotificationResponse delivers payload on main actor")
    func forwardNotificationResponseDeliversPayloadOnMainActor() async {
        let spy = ResponseHandlerSpy()
        let delegate = AppNotificationCenterDelegate { payload in
            MainActor.assumeIsolated {
                spy.receivedPayload = payload
                spy.wasCalledOnMainThread = Thread.isMainThread
            }
        }

        let payload = NotificationResponsePayload(routeKind: "sleepDetail")

        await delegate.forwardNotificationResponse(payload)

        #expect(spy.receivedPayload == payload)
        #expect(spy.wasCalledOnMainThread)
    }
}

@MainActor
private final class ResponseHandlerSpy: @unchecked Sendable {
    var receivedPayload: NotificationResponsePayload?
    var wasCalledOnMainThread = false
}
