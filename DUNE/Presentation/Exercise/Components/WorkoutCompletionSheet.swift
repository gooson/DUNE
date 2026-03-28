import SwiftUI

/// A single PR achieved during this workout session.
struct WorkoutPRAchievement: Sendable, Identifiable {
    let id: String
    let exerciseName: String
    let kind: ActivityPersonalRecord.Kind
    let value: Double
    let previousValue: Double?
}

/// Sheet displayed after saving a workout with effort input and share option.
struct WorkoutCompletionSheet: View {
    let shareImage: UIImage?
    let exerciseName: String
    let setCount: Int
    let effortSuggestion: EffortSuggestion?
    let prAchievements: [WorkoutPRAchievement]
    let onDismiss: (Int?) -> Void

    init(
        shareImage: UIImage?,
        exerciseName: String,
        setCount: Int,
        effortSuggestion: EffortSuggestion?,
        prAchievements: [WorkoutPRAchievement] = [],
        onDismiss: @escaping (Int?) -> Void
    ) {
        self.shareImage = shareImage
        self.exerciseName = exerciseName
        self.setCount = setCount
        self.effortSuggestion = effortSuggestion
        self.prAchievements = prAchievements
        self.onDismiss = onDismiss
    }

    @State private var showCelebration = false
    @State private var effort: Int?
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xl) {
                // Celebration header
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(DS.Color.activity)
                        .scaleEffect(showCelebration ? 1.0 : 0.5)
                        .opacity(showCelebration ? 1.0 : 0)

                    Text("Workout Complete!")
                        .font(.title2.weight(.bold))

                    Text("\(exerciseName) \u{00B7} \(setCount.formattedWithSeparator) sets")
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .padding(.top, DS.Spacing.lg)
                .accessibilityIdentifier("workout-completion-sheet")

                // PR achievements section
                if !prAchievements.isEmpty {
                    prSection
                }

                Spacer()

                // Effort slider (replaces IntensityBadge + RPEInput)
                EffortSliderView(
                    effort: $effort,
                    suggestion: effortSuggestion
                )
                .padding(.horizontal, DS.Spacing.lg)

                Spacer()

                // Share card preview
                if let image = shareImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                }

                // Action buttons
                VStack(spacing: DS.Spacing.sm) {
                    if let image = shareImage {
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview(
                                "\(exerciseName) Workout",
                                image: Image(uiImage: image)
                            )
                        ) {
                            Label("Share Workout", systemImage: "square.and.arrow.up")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.Spacing.md)
                                .background(DS.Color.activity, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                    }

                    Button {
                        onDismiss(effort)
                    } label: {
                        Text("Done")
                            .font(.body.weight(.medium))
                            .foregroundStyle(DS.Color.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.md)
                    }
                    .accessibilityIdentifier("workout-completion-done")
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onDismiss(effort)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(DS.Animation.emphasize) {
                showCelebration = true
            }
        }
        .interactiveDismissDisabled(false)
        .background { SheetWaveBackground() }
    }

    // MARK: - PR Section

    private var prSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                Text(String(localized: "New PR!"))
                    .font(.headline.weight(.bold))
            }

            ForEach(prAchievements) { pr in
                prRow(pr)
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .padding(.horizontal, DS.Spacing.lg)
        .accessibilityIdentifier("workout-completion-pr-section")
    }

    private func prRow(_ pr: WorkoutPRAchievement) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: pr.kind.iconName)
                .font(.caption)
                .foregroundStyle(pr.kind.tintColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(pr.exerciseName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)
                Text(pr.kind.displayName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(pr.value.formattedWithSeparator() + " kg")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.heroTextGradient)
                if let prev = pr.previousValue, prev > 0 {
                    let delta = pr.value - prev
                    Text("+\(delta.formattedWithSeparator()) kg")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.Color.activity)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
