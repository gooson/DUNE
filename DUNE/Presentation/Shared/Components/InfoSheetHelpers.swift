import SwiftUI

/// Shared helpers for info sheet views.
enum InfoSheetHelpers {
    /// Section header with icon + title.
    struct SectionHeader: View {
        let icon: String
        let title: String

        var body: some View {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    /// Bullet point with dot prefix.
    struct BulletPoint: View {
        let text: String

        var body: some View {
            HStack(alignment: .top, spacing: DS.Spacing.xs) {
                Text("·")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.Color.textSecondary)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
    }
}
