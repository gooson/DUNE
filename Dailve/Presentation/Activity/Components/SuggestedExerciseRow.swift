import SwiftUI

/// Single exercise row in the suggested workout section.
/// Supports swipe to reveal alternative exercises.
struct SuggestedExerciseRow: View {
    let exercise: SuggestedExercise
    let onStart: () -> Void
    let onAlternativeSelected: (ExerciseDefinition) -> Void

    @State private var showingAlternatives = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            Button(action: onStart) {
                HStack(spacing: DS.Spacing.sm) {
                    Text(exercise.definition.localizedName)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(exercise.suggestedSets) sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !exercise.alternatives.isEmpty {
                        Button {
                            withAnimation(DS.Animation.snappy) {
                                showingAlternatives.toggle()
                            }
                        } label: {
                            Image(systemName: showingAlternatives ? "chevron.up" : "arrow.left.arrow.right")
                                .font(.caption2)
                                .foregroundStyle(DS.Color.activity)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
            }
            .buttonStyle(.plain)

            // Alternatives (expandable)
            if showingAlternatives {
                VStack(spacing: 0) {
                    ForEach(exercise.alternatives) { alt in
                        Button {
                            onAlternativeSelected(alt)
                        } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)

                                Text(alt.localizedName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.quaternary)
                            }
                            .padding(.vertical, DS.Spacing.xxs)
                            .padding(.leading, DS.Spacing.lg)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
