import Observation
import UIKit

/// Serializes system icon requests while retaining the latest style/theme pair.
@MainActor
@Observable
final class AppIconService {
    static let shared = AppIconService()

    private(set) var isUpdating = false
    private(set) var lastError: String?
    private(set) var appliedConfiguration: AppIconConfiguration?
    private var pendingConfiguration: AppIconConfiguration?

    func synchronize(_ configuration: AppIconConfiguration) async {
        pendingConfiguration = configuration
        guard !isUpdating else { return }
        let application = UIApplication.shared
        guard application.supportsAlternateIcons else {
            lastError = String(localized: "App icon changes are unavailable on this device.")
            return
        }
        guard application.applicationState == .active else { return }

        isUpdating = true
        defer { isUpdating = false }
        while let next = pendingConfiguration {
            guard application.applicationState == .active else { return }
            pendingConfiguration = nil
            let name = next.style.alternateIconName(for: next.theme)
            if application.alternateIconName == name {
                appliedConfiguration = next
                lastError = nil
                continue
            }
            do {
                try await application.setAlternateIconName(name)
                appliedConfiguration = next
                lastError = nil
            } catch {
                lastError = String(localized: "Couldn't update the Home Screen icon. Try again.")
                AppLogger.ui.error("App icon update failed: \(error.localizedDescription)")
            }
        }
    }
}
