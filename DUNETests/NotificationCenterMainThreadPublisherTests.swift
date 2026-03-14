import Combine
import Foundation
import Testing
@testable import DUNE

private actor MainThreadNotificationRecorder {
    private(set) var wasDeliveredOnMainThread = false

    func record(_ value: Bool) {
        wasDeliveredOnMainThread = value
    }
}

@Suite("NotificationCenterMainThreadPublisher")
struct NotificationCenterMainThreadPublisherTests {
    @Test("delivers background-posted notifications on the main thread")
    func deliversBackgroundPostedNotificationsOnTheMainThread() async {
        let center = NotificationCenter()
        let recorder = MainThreadNotificationRecorder()
        let name = Notification.Name("NotificationCenterMainThreadPublisherTests.didPost")
        let (stream, continuation) = AsyncStream<Void>.makeStream()

        let cancellable = center.mainThreadPublisher(for: name).sink { _ in
            let wasDeliveredOnMainThread = Thread.isMainThread
            Task {
                await recorder.record(wasDeliveredOnMainThread)
                continuation.yield(())
                continuation.finish()
            }
        }
        defer { cancellable.cancel() }

        let postingThread = Thread {
            center.post(name: name, object: nil)
        }
        postingThread.start()

        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        let wasDeliveredOnMainThread = await recorder.wasDeliveredOnMainThread
        #expect(wasDeliveredOnMainThread)
    }
}
