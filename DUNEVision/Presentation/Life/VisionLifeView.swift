import SwiftUI

/// visionOS Life tab showing habit tracking information.
/// Habits are stored in SwiftData on iOS, so this view provides
/// a read-only summary and directs users to their iPhone.
struct VisionLifeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Habits")
                .font(.title.weight(.bold))

            Text("Your habits are tracked on your iPhone. Open DUNE on your iPhone to view, create, and complete habits.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .navigationTitle("Life")
    }
}
