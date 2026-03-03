import SwiftUI

// MARK: - Environment Key (Watch)

private struct WatchAppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .desertWarm
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[WatchAppThemeKey.self] }
        set { self[WatchAppThemeKey.self] = newValue }
    }
}
