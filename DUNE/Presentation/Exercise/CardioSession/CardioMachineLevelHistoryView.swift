import SwiftUI
import Charts

/// Machine level selections plotted against active workout time.
struct CardioMachineLevelHistoryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let changes: [CardioMachineLevelChange]
    let duration: TimeInterval

    @State private var selectedElapsed: Double?

    struct LevelPoint: Identifiable {
        let elapsed: Double
        let level: Int
        var id: Double { elapsed }
    }

    private var orderedChanges: [CardioMachineLevelChange] {
        changes.sorted { $0.elapsedSeconds < $1.elapsedSeconds }
    }

    private var plotPoints: [LevelPoint] { Self.plotPoints(changes: changes, duration: duration) }

    static func plotPoints(changes: [CardioMachineLevelChange], duration: TimeInterval) -> [LevelPoint] {
        var points: [LevelPoint] = []
        for change in changes.sorted(by: { $0.elapsedSeconds < $1.elapsedSeconds }) {
            let point = LevelPoint(elapsed: change.elapsedSeconds, level: change.level)
            if points.last?.elapsed == point.elapsed {
                points[points.count - 1] = point
            } else {
                points.append(point)
            }
        }
        if let last = points.last, duration.isFinite, duration > last.elapsed {
            points.append(LevelPoint(elapsed: duration, level: last.level))
        }
        return points
    }

    private var selectedChange: CardioMachineLevelChange? {
        guard let selectedElapsed else { return orderedChanges.first }
        return orderedChanges.last(where: { $0.elapsedSeconds <= selectedElapsed }) ?? orderedChanges.first
    }

    var body: some View {
        if !changes.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Label("Level History", systemImage: "chart.xyaxis.line")
                    .font(.headline)

                if let selectedChange {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text("Elapsed Time")
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                            Text(selectedChange.formattedElapsed)
                                .font(.title3.weight(.semibold).monospacedDigit())
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                            Text("Level")
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                            Text(selectedChange.level.formatted())
                                .font(.title.weight(.bold).monospacedDigit())
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("cardio-level-history-selection")
                }

                Chart(plotPoints) { point in
                    LineMark(
                        x: .value("Elapsed Time", point.elapsed),
                        y: .value("Level", point.level)
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(DS.Color.activity)
                }
                .chartXScale(domain: 0...max(max(duration.isFinite ? duration : 0, plotPoints.last?.elapsed ?? 1), 1))
                .chartYScale(domain: 0...(max(plotPoints.map(\.level).max() ?? 1, 1) + 1))
                .chartXSelection(value: $selectedElapsed)
                .frame(height: 130)
                .clipped()
                .accessibilityIdentifier("cardio-level-history-chart")

                LazyVStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    ForEach(orderedChanges.indices, id: \.self) { index in
                        let change = orderedChanges[index]
                        let elapsed = change.formattedElapsed
                        let rowLayout = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
                            : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
                        rowLayout {
                            Text(elapsed)
                                .monospacedDigit()
                                .foregroundStyle(DS.Color.textSecondary)
                            if !dynamicTypeSize.isAccessibilitySize {
                                Spacer(minLength: DS.Spacing.sm)
                            }
                            Text("Level")
                            Text(change.level.formatted())
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .font(.subheadline)
                        .padding(.vertical, DS.Spacing.xs)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedElapsed = change.elapsedSeconds }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            Text("Elapsed Time") + Text(verbatim: ": \(elapsed), ")
                            + Text("Level") + Text(verbatim: " \(change.level)")
                        )
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("cardio-level-history-row-\(index)")
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .accessibilityIdentifier("cardio-level-history")
        }
    }
}

#Preview {
    CardioMachineLevelHistoryView(changes: [
        CardioMachineLevelChange(elapsedSeconds: 0, level: 5)!,
        CardioMachineLevelChange(elapsedSeconds: 270, level: 7)!
    ], duration: 600)
}
