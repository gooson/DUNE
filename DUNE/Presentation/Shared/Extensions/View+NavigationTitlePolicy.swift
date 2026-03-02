import SwiftUI

extension View {
    /// Product rule: navigation titles stay fixed in English across locales.
    func englishNavigationTitle(_ title: String) -> some View {
        navigationTitle(Text(verbatim: title))
    }
}
