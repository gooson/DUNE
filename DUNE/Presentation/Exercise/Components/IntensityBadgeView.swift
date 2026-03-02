import SwiftUI

/// Compact badge showing workout effort (1-10) with category label.
/// Used in history lists and session detail views.
struct IntensityBadgeView: View {
    let effort: Int

    var body: some View {
        let category = EffortCategory(effort: effort)
        let categoryColor = category.color

        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: category.iconName)
                .foregroundStyle(categoryColor)
                .font(.body.weight(.semibold))

            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(categoryColor)

                Text("Effort \u{00B7} \(effort)/10")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Mini effort dots
            HStack(spacing: 3) {
                ForEach(1...10, id: \.self) { i in
                    Circle()
                        .fill(i <= effort ? categoryColor : Color.secondary.opacity(0.2))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(categoryColor.opacity(DS.Opacity.border))
        }
    }
}
