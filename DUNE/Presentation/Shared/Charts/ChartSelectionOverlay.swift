import SwiftUI

/// Shared selection overlay shown on chart interaction.
/// Displays date and value in a material-backed capsule at the top of the chart.
struct ChartSelectionOverlay: View {
    let date: Date
    let value: String
    var dateFormat: Date.FormatStyle = .dateTime.month(.abbreviated).day()

    var body: some View {
        HStack {
            Text(date, format: dateFormat)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.caption)
        .foregroundStyle(.primary)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        .padding(.horizontal, DS.Spacing.xs)
    }
}
