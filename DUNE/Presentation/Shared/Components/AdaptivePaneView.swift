import SwiftUI

/// Keeps related content and controls together as the available window changes.
/// Place outside ScrollView; each pane owns its scrolling and keyboard avoidance.
struct AdaptivePaneView<Primary: View, Secondary: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let primary: Primary
    let secondary: Secondary

    init(@ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary) {
        self.primary = primary()
        self.secondary = secondary()
    }

    var body: some View {
        // Module version gates compilation on SDKs predating ArrangementView.
        #if canImport(SwiftUI, _version: 8.0.85)
        if #available(iOS 27.1, macOS 27.1, visionOS 27.1, *) {
            ArrangementView {
                primary
            } secondary: {
                secondary
            }
            .arrangementViewStyle(.split)
        } else {
            fallback
        }
        #else
        fallback
        #endif
    }

    private var fallback: some View {
        let layout = sizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(HStackLayout(alignment: .top, spacing: DS.Spacing.lg))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
        return layout {
            primary.frame(maxWidth: .infinity)
            secondary.frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    AdaptivePaneView {
        Text("Workout")
    } secondary: {
        Text("Rest Timer")
    }
}
