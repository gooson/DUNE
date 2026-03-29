import SwiftUI

/// Data model for generating a shareable PR card image.
struct PRShareData: Sendable {
    let exerciseName: String
    let kindDisplayName: String
    let kindIconName: String
    let formattedValue: String
    let unitLabel: String?
    let formattedDelta: String?
    let date: Date
}

/// Shareable personal record card rendered as a SwiftUI View.
/// Used with ImageRenderer to produce a sharable image.
struct PRShareCard: View {
    let data: PRShareData
    let accentColor: Color

    private var formattedDate: String {
        data.date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 20)

            // Divider
            Rectangle()
                .fill(.white.opacity(0.15))
                .frame(height: 1)

            // PR Value
            valueSection
                .padding(.horizontal, 24)
                .padding(.vertical, 24)

            // Divider
            Rectangle()
                .fill(.white.opacity(0.15))
                .frame(height: 1)

            // Footer
            footer
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
        .frame(width: 360)
        .background(ShareCardPalette.backgroundGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Personal Record")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))

                Text(data.exerciseName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Kind badge
            VStack(spacing: 2) {
                Image(systemName: data.kindIconName)
                    .font(.caption)
                    .foregroundStyle(accentColor)
                Text(data.kindDisplayName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(accentColor)
            }
        }
    }

    // MARK: - Value

    private var valueSection: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(data.formattedValue)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if let unit = data.unitLabel {
                    Text(unit)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            if let delta = data.formattedDelta {
                Text(delta)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DS.Color.positive)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(DS.Color.positive.opacity(0.2), in: Capsule())
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(DS.Color.positive)
                Text("DUNE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }
}

/// Reuse the same palette as WorkoutShareCard for visual consistency.
private enum ShareCardPalette {
    static let backgroundGradient = LinearGradient(
        colors: [
            Color("ShareCardGradientStart"),
            Color("ShareCardGradientEnd")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
