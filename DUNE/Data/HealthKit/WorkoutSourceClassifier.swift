import Foundation

enum WorkoutSourceClassifier {
    /// Returns true when HealthKit sample source belongs to this app family
    /// (main iOS app or watch companion targets).
    static func isFromAppFamily(
        sourceBundleIdentifier: String,
        appBundleIdentifier: String = Bundle.main.bundleIdentifier ?? ""
    ) -> Bool {
        guard !appBundleIdentifier.isEmpty else { return false }
        if sourceBundleIdentifier == appBundleIdentifier { return true }

        // Companion/watch extensions usually use a child bundle identifier
        // (for example: com.example.app.watchkitapp).
        let isChildBundle = sourceBundleIdentifier.hasPrefix("\(appBundleIdentifier).")
        return isChildBundle && sourceBundleIdentifier.localizedCaseInsensitiveContains("watch")
    }
}
