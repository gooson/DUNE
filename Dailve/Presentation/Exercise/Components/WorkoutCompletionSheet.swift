import SwiftUI

/// Sheet displayed after saving a workout, offering a share option.
struct WorkoutCompletionSheet: View {
    let shareImage: UIImage?
    let exerciseName: String
    let setCount: Int
    let onDismiss: () -> Void

    @State private var showCelebration = false

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

                    Text("\(exerciseName) \u{00B7} \(setCount) sets")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, DS.Spacing.lg)

                Spacer()

                // Share card preview
                if let image = shareImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                }

                Spacer()

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
                        onDismiss()
                    } label: {
                        Text("Done")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
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
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
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
    }
}
