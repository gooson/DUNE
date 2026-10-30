import SwiftUI

/// Compact app-supplied content; Siri owns the surrounding dialogue and voice.
struct HealthQuerySnippetView: View {
    let result: HealthQueryResult

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label(result.title, systemImage: result.kind.symbolName)
                .font(.headline)
            Text("Period: \(result.interval.start.formatted(date: .abbreviated, time: .omitted)) – \(result.interval.end.addingTimeInterval(-0.001).formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            switch result.status {
            case .locked:
                Label("Unlock your device to view health data.", systemImage: "lock")
            case .noData:
                Label("No records found for this period.", systemImage: "tray")
            case .unavailable, .invalidRequest:
                Text("This information is unavailable.")
            case .available, .partial:
                ForEach(result.metrics.filter(\.value.isFinite).prefix(3)) { metric in
                    HStack(alignment: .firstTextBaseline) {
                        Text(metric.title)
                        Spacer()
                        Text(metric.unit.formatted(metric.value) + " " + metric.unit.displayUnit(for: metric.value))
                            .bold()
                    }
                    .font(.subheadline)
                }
                if result.metrics.isEmpty, let record = result.records.first, result.kind != .report {
                    Text(record.name).font(.title3.bold())
                    Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                }
                if result.status == .partial { Text("Some records may be missing.").font(.caption) }
                if result.kind == .report { Text("Workout notes are excluded.").font(.caption) }
                if let source = result.sources.first {
                    Label(source.kind == .healthKit ? String(localized: "Apple Health") : String(localized: "DUNE record"),
                          systemImage: "checkmark.seal")
                        .font(.caption)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}
