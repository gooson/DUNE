import Foundation

/// Light activity suggestion for rest/recovery days
struct ActiveRecoverySuggestion: Identifiable, Sendable {
    let id: String
    let title: String
    let iconName: String  // SF Symbol name
    let duration: String

    static let defaults: [ActiveRecoverySuggestion] = [
        .init(id: "walking", title: "Light Walking", iconName: "figure.walk", duration: "20-30 min"),
        .init(id: "stretching", title: "Stretching", iconName: "figure.flexibility", duration: "10 min"),
        .init(id: "yoga", title: "Yoga Flow", iconName: "figure.yoga", duration: "15 min"),
    ]
}
