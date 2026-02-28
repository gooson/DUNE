import Foundation

/// Presentation-layer DTO for insight cards on the Today tab.
/// Bridges domain `CoachingInsight` to SwiftUI rendering.
struct InsightCardData: Identifiable, Hashable, Sendable {
    let id: String
    let category: InsightCategory
    let title: String
    let message: String
    let iconName: String
    let actionHint: String?
    let priority: InsightPriority

    init(from insight: CoachingInsight) {
        self.id = insight.id
        self.category = insight.category
        self.title = insight.title
        self.message = insight.message
        self.iconName = insight.iconName
        self.actionHint = insight.actionHint
        self.priority = insight.priority
    }
}
