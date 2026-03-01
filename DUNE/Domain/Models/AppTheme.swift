import Foundation

/// App-wide visual theme selection.
///
/// Persisted via `UserDefaults` with key ``UserDefaultsKey/appTheme``.
/// Propagated to the view hierarchy via `\.appTheme` environment value.
enum AppTheme: String, CaseIterable, Codable, Sendable {
    case desertWarm
    case oceanCool
    case forestGreen
}
