import Foundation

/// Light activity suggestion for rest/recovery days
struct ActiveRecoverySuggestion: Identifiable, Sendable {
    let id: String
    let title: String
    let iconName: String  // SF Symbol name
    let duration: String

    static let defaults: [ActiveRecoverySuggestion] = [
        .init(id: "walking", title: String(localized: "Light Walking"), iconName: "figure.walk", duration: String(localized: "20-30 min")),
        .init(id: "stretching", title: String(localized: "Stretching"), iconName: "figure.flexibility", duration: String(localized: "10 min")),
        .init(id: "yoga", title: String(localized: "Yoga Flow"), iconName: "figure.yoga", duration: String(localized: "15 min")),
    ]
}
