import SwiftUI

/// Single exercise row in the suggested workout section.
/// Separates "start" and "alternatives" actions to reduce interaction ambiguity.
struct SuggestedExerciseRow: View {
    let exercise: SuggestedExercise
    let isExcluded: Bool
    let onShowDetails: () -> Void
    let onStart: () -> Void
    let onToggleInterest: () -> Void
    let onShowAlternativeDetails: (ExerciseDefinition) -> Void

    @Environment(\.appTheme) private var theme
    @State private var showingAlternatives = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Button(action: onShowDetails) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(exercise.definition.localizedName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.sandColor)
                            .lineLimit(2)

                        Text(exercise.reason)
                            .font(.caption2)
                            .foregroundStyle(DS.Color.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: DS.Spacing.xs)

                    HStack(spacing: DS.Spacing.xs) {
                        Text(
                            String.localizedStringWithFormat(
                                String(localized: "%lld sets"),
                                Int64(exercise.suggestedSets)
                            )
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.Color.textSecondary)

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.xs) {
                    Button("Start", action: onStart)
                        .buttonStyle(.borderedProminent)
                        .tint(DS.Color.activity)
                        .font(.caption.weight(.semibold))
                        .controlSize(.small)

                    if !exercise.alternatives.isEmpty {
                        Button(showingAlternatives ? String(localized: "Hide") : String(localized: "Alternatives")) {
                            withAnimation(DS.Animation.snappy) {
                                showingAlternatives.toggle()
                            }
                        }
                        .buttonStyle(.bordered)
                        .font(.caption.weight(.semibold))
                        .controlSize(.small)
                    }

                    Spacer(minLength: DS.Spacing.xs)
                }

                HStack(spacing: DS.Spacing.xs) {
                    Spacer(minLength: 0)

                    Button {
                        onToggleInterest()
                    } label: {
                        HStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: isExcluded ? "eye.slash.fill" : "eye.slash")
                                .font(.caption2)
                            Text(isExcluded ? String(localized: "Undo") : String(localized: "Not Interested"))
                                .font(.caption2.weight(.semibold))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isExcluded ? DS.Color.activity : DS.Color.textSecondary)
                }
            }

            // Alternatives (expandable)
            if showingAlternatives {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Alternative options")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, DS.Spacing.xs)

                    ForEach(exercise.alternatives) { alt in
                        Button {
                            onShowAlternativeDetails(alt)
                        } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)

                                Text(alt.localizedName)
                                    .font(.caption)
                                    .foregroundStyle(DS.Color.textSecondary)
                                    .lineLimit(1)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.quaternary)
                            }
                            .padding(.vertical, DS.Spacing.xxs)
                            .padding(.leading, DS.Spacing.md)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DS.Spacing.sm)
                .background(DS.Color.activity.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, DS.Spacing.xxs)
    }
}
