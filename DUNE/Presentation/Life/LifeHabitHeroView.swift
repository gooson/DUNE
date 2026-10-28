import SwiftUI

/// Today's completion scene. The terrain and medals are decorative; habits below own all actions.
struct LifeHabitHeroView: View {
    let completedCount: Int
    let totalCount: Int
    let progresses: [HabitProgress]

    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    private var completed: Int { min(max(0, completedCount), max(0, totalCount)) }
    private var total: Int { max(0, totalCount) }
    private var remaining: Int { max(0, total - completed) }
    private var fraction: CGFloat { total > 0 ? CGFloat(completed) / CGFloat(total) : 0 }
    private var gold: Color { theme == .desertWarm ? DS.Color.desertBronze : theme.accentColor }
    private var lightGold: Color { theme == .desertWarm ? DS.Color.warmGlow : theme.sandColor }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("HABITS")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(gold)
                    .accessibilityIdentifier("life-hero-heading")
                Spacer()
                Text("Today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if total == 0 {
                Text("No habits today")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: DS.Spacing.xl) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        ring
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        if dynamicTypeSize.isAccessibilitySize {
                            Text("\(completed) of \(total) complete")
                                .font(.headline)
                                .accessibilityIdentifier("life-hero-external-progress")
                        }
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                            Text(remaining.formatted())
                                .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 52 : 64, weight: .bold, design: .rounded))
                                .minimumScaleFactor(0.75)
                                .monospacedDigit()
                                .foregroundStyle(gold)
                                .accessibilityIdentifier("life-hero-remaining")
                            Text("Remaining")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        if !dynamicTypeSize.isAccessibilitySize {
                            medals
                                .accessibilityHidden(true)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.xxl, style: .continuous)
                .fill(theme.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.xxl, style: .continuous)
                        .fill(LinearGradient(colors: [gold.opacity(colorScheme == .dark ? 0.15 : 0.08), lightGold.opacity(0.06), .clear], startPoint: .topTrailing, endPoint: .bottomLeading))
                }
                .overlay(alignment: .bottom) {
                    LifeHeroTerrain()
                        .stroke(LinearGradient(colors: [gold.opacity(0.08), lightGold.opacity(0.38), gold.opacity(0.12)], startPoint: .leading, endPoint: .trailing), lineWidth: 1)
                        .frame(height: 72)
                        .clipped()
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.xxl, style: .continuous)
                        .strokeBorder(gold.opacity(DS.Opacity.cardBorder), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xxl, style: .continuous))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("life-habit-hero")
    }

    private var ring: some View {
        ZStack {
            Circle()
                .fill(gold.opacity(0.08))
                .padding(13)
            Circle()
                .stroke(gold.opacity(0.17), lineWidth: 7)
            if fraction > 0 {
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(AngularGradient(colors: [gold, lightGold, gold], center: .center), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Text("\(completed) / \(total)")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .monospacedDigit()
                Text("Done")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 104, height: 104)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(completed) of \(total) complete"))
        .accessibilityIdentifier("life-hero-ring")
    }

    private var medals: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(Array(progresses.prefix(5))) { progress in
                Image(systemName: progress.iconCategory.iconName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(progress.isCompleted ? lightGold : gold.opacity(0.65))
                    .frame(width: 25, height: 25)
                    .background {
                        Circle().fill(progress.isCompleted ? gold : gold.opacity(0.09))
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if progress.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(lightGold)
                        }
                    }
            }
            if total > 5 {
                Text("+\(total - 5)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LifeHeroTerrain: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for offset in stride(from: 0.0, through: 28.0, by: 7.0) {
            path.move(to: CGPoint(x: 0, y: rect.height * 0.73 + offset))
            path.addQuadCurve(to: CGPoint(x: rect.maxX * 0.52, y: rect.height * 0.58 + offset), control: CGPoint(x: rect.maxX * 0.23, y: rect.height * 0.12 + offset))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.height * 0.26 + offset), control: CGPoint(x: rect.maxX * 0.78, y: rect.height * 0.88 + offset))
        }
        return path
    }
}
