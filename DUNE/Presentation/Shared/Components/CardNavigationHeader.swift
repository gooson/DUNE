import SwiftUI

/// A card's title and disclosure share one label; the caller owns navigation.
struct CardNavigationHeader<Title: View>: View {
    var showsChevron = true
    var minimumHeight: CGFloat = 44
    @ViewBuilder let title: () -> Title

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            title()
                .fixedSize(horizontal: false, vertical: true)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("card-navigation-header")
    }
}

struct CardNavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

#Preview {
    Button {} label: {
        CardNavigationHeader {
            Label("Recovery & Sleep", systemImage: "bed.double.fill")
                .font(.headline)
        }
    }
    .buttonStyle(CardNavigationButtonStyle())
    .padding()
}
