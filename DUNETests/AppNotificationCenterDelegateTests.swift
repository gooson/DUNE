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

    @Test("forwardNotificationResponse delivers payload on main thread")
    func forwardNotificationResponseDeliversPayloadOnMainThread() async {
        let spy = ResponseHandlerSpy()
        let delegate = AppNotificationCenterDelegate { payload in
            MainActor.assumeIsolated {
                spy.receivedPayload = payload
                spy.wasCalledOnMainThread = Thread.isMainThread
            }
        }

        let payload = NotificationResponsePayload(routeKind: "sleepDetail")

        await withCheckedContinuation { continuation in
            delegate.forwardNotificationResponse(payload) {
                continuation.resume()
            }
        }

        #expect(spy.receivedPayload == payload)
        #expect(spy.wasCalledOnMainThread)
    }

    @Test("forwardNotificationResponse calls completion handler on main thread")
    func forwardNotificationResponseCallsCompletionOnMainThread() async {
        let delegate = AppNotificationCenterDelegate { _ in }

        let payload = NotificationResponsePayload(routeKind: "workoutDetail")

        let completionOnMain = await withCheckedContinuation { continuation in
            delegate.forwardNotificationResponse(payload) {
                continuation.resume(returning: Thread.isMainThread)
            }
        }

        #expect(completionOnMain)
    }
}

@MainActor
private final class ResponseHandlerSpy: @unchecked Sendable {
    var receivedPayload: NotificationResponsePayload?
    var wasCalledOnMainThread = false
}
