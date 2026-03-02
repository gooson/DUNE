import SwiftUI

/// Sheet displayed after saving a workout with effort input and share option.
struct WorkoutCompletionSheet: View {
    let shareImage: UIImage?
    let exerciseName: String
    let setCount: Int
    let effortSuggestion: EffortSuggestion?
    let onDismiss: (Int?) -> Void

    @State private var showCelebration = false
    @State private var effort: Int?

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
}
