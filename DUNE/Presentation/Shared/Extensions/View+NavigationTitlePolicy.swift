import SwiftUI

extension View {
    /// Product rule: navigation titles stay fixed in English across locales.
    func englishNavigationTitle(_ title: String) -> some View {
        navigationTitle(Text(verbatim: title))
    }

    /// Gives a pending or unavailable push destination the same viewport as its loaded content.
    func detailStatusSurface() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { DetailWaveBackground() }
    }
}
