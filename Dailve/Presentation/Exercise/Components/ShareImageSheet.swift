import SwiftUI

/// Identifiable wrapper for UIImage to use with `.sheet(item:)`.
struct ShareableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Reusable sheet for sharing a rendered workout image.
struct ShareImageSheet: View {
    let image: UIImage
    let title: String

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                Spacer()

                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

                Spacer()

                ShareLink(
                    item: Image(uiImage: image),
                    preview: SharePreview(title, image: Image(uiImage: image))
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(DS.Color.activity, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
            }
            .navigationTitle("Share Workout")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
