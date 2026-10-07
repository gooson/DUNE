import CoreData
import UIKit

/// Keeps Core Data's CloudKit setup from being suspended while it holds a store lock.
@MainActor
final class CloudKitSetupBackgroundTask {
    typealias BeginTask = (@escaping @MainActor @Sendable () -> Void) -> UIBackgroundTaskIdentifier
    typealias EndTask = (UIBackgroundTaskIdentifier) -> Void

    private let beginTask: BeginTask
    private let endTask: EndTask
    private var observer: NSObjectProtocol?
    private var activeSetupEvents: Set<UUID> = []
    private var taskIdentifier: UIBackgroundTaskIdentifier = .invalid

    init(
        beginTask: @escaping BeginTask = { expirationHandler in
            UIApplication.shared.beginBackgroundTask(
                withName: "CloudKit Setup",
                expirationHandler: expirationHandler
            )
        },
        endTask: @escaping EndTask = { UIApplication.shared.endBackgroundTask($0) }
    ) {
        self.beginTask = beginTask
        self.endTask = endTask
    }

    func startObserving() {
        guard observer == nil else { return }

        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  event.type == .setup else { return }

            MainActor.assumeIsolated {
                self?.handleSetupEvent(identifier: event.identifier, isFinished: event.endDate != nil)
            }
        }
    }

    func handleSetupEvent(identifier: UUID, isFinished: Bool) {
        if isFinished {
            guard activeSetupEvents.remove(identifier) != nil else { return }
            if activeSetupEvents.isEmpty {
                finishTask()
            }
            return
        }

        guard activeSetupEvents.insert(identifier).inserted else { return }
        guard taskIdentifier == .invalid else { return }
        taskIdentifier = beginTask { [weak self] in
            self?.finishTask()
        }
    }

    private func finishTask() {
        guard taskIdentifier != .invalid else { return }
        let identifier = taskIdentifier
        taskIdentifier = .invalid
        endTask(identifier)
    }
}
