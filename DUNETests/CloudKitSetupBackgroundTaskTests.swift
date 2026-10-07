import Foundation
import Testing
import UIKit
@testable import DUNE

@Suite("CloudKitSetupBackgroundTask")
@MainActor
struct CloudKitSetupBackgroundTaskTests {
    @Test("Protects setup until its matching completion")
    func setupCompletion() {
        let recorder = BackgroundTaskRecorder()
        let task = makeTask(recorder: recorder)
        let eventID = UUID()

        task.handleSetupEvent(identifier: eventID, isFinished: false)
        #expect(recorder.beginCount == 1)
        #expect(recorder.endedIdentifiers.isEmpty)

        task.handleSetupEvent(identifier: eventID, isFinished: true)
        #expect(recorder.endedIdentifiers == [1])
    }

    @Test("Overlapping setup events share one assertion")
    func overlappingEvents() {
        let recorder = BackgroundTaskRecorder()
        let task = makeTask(recorder: recorder)
        let firstID = UUID()
        let secondID = UUID()

        task.handleSetupEvent(identifier: firstID, isFinished: false)
        task.handleSetupEvent(identifier: firstID, isFinished: false)
        task.handleSetupEvent(identifier: secondID, isFinished: false)
        task.handleSetupEvent(identifier: firstID, isFinished: true)
        #expect(recorder.beginCount == 1)
        #expect(recorder.endedIdentifiers.isEmpty)

        task.handleSetupEvent(identifier: secondID, isFinished: true)
        task.handleSetupEvent(identifier: secondID, isFinished: true)
        #expect(recorder.endedIdentifiers == [1])
    }

    @Test("Expiration ends the assertion once")
    func expiration() {
        let recorder = BackgroundTaskRecorder()
        let task = makeTask(recorder: recorder)
        let eventID = UUID()

        task.handleSetupEvent(identifier: eventID, isFinished: false)
        recorder.expirationHandler?()
        task.handleSetupEvent(identifier: eventID, isFinished: true)

        #expect(recorder.endedIdentifiers == [1])
    }

    private func makeTask(recorder: BackgroundTaskRecorder) -> CloudKitSetupBackgroundTask {
        CloudKitSetupBackgroundTask(
            beginTask: { expirationHandler in
                recorder.beginCount += 1
                recorder.expirationHandler = expirationHandler
                return UIBackgroundTaskIdentifier(rawValue: recorder.beginCount)
            },
            endTask: { recorder.endedIdentifiers.append($0.rawValue) }
        )
    }
}

@MainActor
private final class BackgroundTaskRecorder {
    var beginCount = 0
    var endedIdentifiers: [Int] = []
    var expirationHandler: (@MainActor @Sendable () -> Void)?
}
