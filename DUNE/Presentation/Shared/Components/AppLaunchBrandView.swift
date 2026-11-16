import SwiftUI

/// Shared by the launch splash and its live Settings preview.
struct AppLaunchBrandView: View {
    let style: AppIconStyle
    let theme: AppTheme

    var body: some View {
        GeometryReader { geometry in
            let size = min(280, min(geometry.size.width * 0.62, geometry.size.height * 0.64))
            ZStack {
                theme.appIconBackgroundColor
                Image(style.launchBrandAssetName(for: theme))
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .accessibilityLabel("DUNE")
                    .accessibilityValue(style.displayName)
                    .accessibilityIdentifier("launch-brand-\(style.rawValue)-\(theme.rawValue)")
            }
        }
    }
}

#Preview {
    AppLaunchBrandView(style: .interleave, theme: .desertWarm)
}
