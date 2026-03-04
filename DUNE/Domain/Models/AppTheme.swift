import Foundation

/// App-wide visual theme selection.
///
/// Persisted via `UserDefaults` with key ``UserDefaultsKey/appTheme``.
/// Propagated to the view hierarchy via `\.appTheme` environment value.
enum AppTheme: String, CaseIterable, Codable, Sendable {
    case desertWarm  = "desertWarm"
    case oceanCool   = "oceanCool"
    case forestGreen = "forestGreen"
    case sakuraCalm  = "sakuraCalm"
    case arcticDawn  = "arcticDawn"
    case solarPop    = "solarPop"
    case shanksRed   = "shanksRed"
}

extension AppTheme {
    static let storageKey = "com.dune.app.theme"

    /// Resolves persisted raw values with backward-compatible alias handling.
    ///
    /// Supported legacy aliases:
    /// - "artic"
    /// - "articDawn"
    static func resolvedTheme(fromPersistedRawValue rawValue: String?) -> AppTheme? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let direct = AppTheme(rawValue: trimmed) {
            return direct
        }

        switch trimmed.lowercased() {
        case "artic", "articdawn", "arctic", "arcticdawn":
            return .arcticDawn
        default:
            return nil
        }
    }

    static func normalizedRawValue(fromPersistedRawValue rawValue: String?) -> String? {
        resolvedTheme(fromPersistedRawValue: rawValue)?.rawValue
    }
}
