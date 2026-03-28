import SwiftUI

/// Shared empty-state placeholder shown when sleep card data is not yet available.
struct SleepDataPlaceholder: View {
    var body: some View {
        Text("Collecting sleep data...")
            .font(.subheadline)
            .foregroundStyle(DS.Color.textSecondary)
    }
}
