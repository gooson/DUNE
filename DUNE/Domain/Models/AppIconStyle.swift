import Foundation

/// The three approved silhouettes. Color is derived from AppTheme.
enum AppIconStyle: String, CaseIterable, Codable, Sendable {
    case interleave
    case ocean
    case flow

    static let storageKey = "com.dune.app.icon.style"
    static let defaultStyle: AppIconStyle = .interleave

    var sourceConceptNumber: Int {
        switch self {
        case .interleave: 82
        case .ocean: 71
        case .flow: 87
        }
    }
}

struct AppIconConfiguration: Hashable, Sendable {
    let style: AppIconStyle
    let theme: AppTheme
}
