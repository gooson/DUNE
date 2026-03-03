import Foundation
import HealthKit

/// Persists HKQueryAnchor per sample type so background delivery only processes new samples.
/// Key prefix uses bundle identifier for test/production isolation (correction #76).
final class HealthKitAnchorStore: @unchecked Sendable {
    static let shared = HealthKitAnchorStore()

    private let defaults: UserDefaults
    private let keyPrefix: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.keyPrefix = (Bundle.main.bundleIdentifier ?? "com.dailve") + ".hkAnchor."
    }

    /// Returns the stored anchor for the given sample type, or nil if none.
    func anchor(for sampleType: HKSampleType) -> HKQueryAnchor? {
        let key = keyPrefix + sampleType.identifier
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        } catch {
            // Corrupted anchor — reset
            defaults.removeObject(forKey: key)
            return nil
        }
    }

    /// Saves the anchor for the given sample type.
    func saveAnchor(_ anchor: HKQueryAnchor, for sampleType: HKSampleType) {
        let key = keyPrefix + sampleType.identifier
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            defaults.set(data, forKey: key)
        } catch {
            AppLogger.healthKit.error("[AnchorStore] Failed to archive anchor for \(sampleType.identifier): \(error.localizedDescription)")
        }
    }
}
