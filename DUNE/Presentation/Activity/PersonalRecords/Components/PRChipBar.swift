import SwiftUI

/// Horizontal scroll chip bar for selecting PR metric kinds.
struct PRChipBar: View {
    let kinds: [ActivityPersonalRecord.Kind]
    @Binding var selected: ActivityPersonalRecord.Kind?

    @Namespace private var chipAnimation

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(kinds, id: \.self) { kind in
                        chipButton(kind)
                    }
                }
                .padding(.horizontal, DS.Spacing.sm)
            }
            .onChange(of: selected) { _, newKind in
                if let newKind {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        proxy.scrollTo(newKind, anchor: .center)
                    }
                }
            }
        }
        .accessibilityIdentifier("activity-personal-records-chip-bar")
    }

    private func chipButton(_ kind: ActivityPersonalRecord.Kind) -> some View {
        let isSelected = kind == selected

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selected = kind
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: kind.iconName)
                    .font(.system(size: 12))
                Text(kind.displayName)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : DS.Color.textSecondary)
            .background {
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(kind.tintColor) : AnyShapeStyle(.ultraThinMaterial))
                    .matchedGeometryEffect(id: kind, in: chipAnimation, isSource: isSelected)
            }
        }
        .buttonStyle(.plain)
        .id(kind)
        .accessibilityLabel(kind.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
