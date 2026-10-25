import SwiftUI

/// Supporting surface used by the Today progress and briefing cards.
struct DashboardSupportCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    @Environment(\.appTheme) private var theme

    var body: some View {
        Group {
            if theme == .desertWarm {
                content()
                    .padding(17)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        DesertCardSurface(cornerRadius: 18, isSupporting: true)
                    }
            } else {
                StandardCard(padding: 17, content: content)
            }
        }
    }
}

#Preview {
    DashboardSupportCard {
        Text("Today")
    }
    .padding()
}
