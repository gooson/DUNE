import Combine
import Foundation

extension NotificationCenter {
    /// Delivers notification publisher output on the main run loop so SwiftUI
    /// state mutations triggered from `.onReceive` stay on the UI thread.
    func mainThreadPublisher(
        for name: Notification.Name,
        object: AnyObject? = nil
    ) -> AnyPublisher<Notification, Never> {
        publisher(for: name, object: object)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}
