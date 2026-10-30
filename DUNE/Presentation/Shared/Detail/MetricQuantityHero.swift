import SwiftUI

/// Hero for the resolved current quantity and its original measurement date.
@MainActor
struct MetricQuantityHero: View {
    let metric: HealthMetric
    var unitOverride: String? = nil

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 24
    @ScaledMetric(relativeTo: .title2) private var iconColumn: CGFloat = 44
    @ScaledMetric(relativeTo: .largeTitle) private var quantitySize: CGFloat = 52

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }
    private var formatter: MetricDetailValueFormatter {
        MetricDetailValueFormatter(category: metric.category, unitOverride: unitOverride)
    }
    private var formattedValue: String { formatter.string(from: metric.value) }
    private var resolvedUnit: String { formatter.unit }
    private var radius: CGFloat { sizeClass == .regular ? DS.Radius.xxl : DS.Radius.xl }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            identity
            quantity
            Text("Updated \(metric.date, format: .relative(presentation: .named))")
                .font(.caption2)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: radius)
                .fill(palette.surface)
                .overlay(alignment: .bottom) {
                    lowDunes
                        .clipShape(RoundedRectangle(cornerRadius: radius))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(palette.border, lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.category.displayName), \(formattedValue) \(resolvedUnit)")
        .accessibilityIdentifier("metric-summary-header")
    }

    private var identity: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            Image(systemName: metric.resolvedIconName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(palette.ink)
                .frame(width: iconColumn, height: iconColumn)
                .background(palette.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .accessibilityHidden(true)
            Text(metric.category.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var quantity: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                valueText
                unitText
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    valueText
                    unitText
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    valueText
                    unitText
                }
            }
        }
    }

    private var valueText: some View {
        Text(formattedValue)
            .font(dynamicTypeSize.isAccessibilitySize
                  ? .largeTitle.weight(.semibold)
                  : .system(size: quantitySize, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(LinearGradient(
                colors: [palette.heroHighlight, palette.heroAccent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var unitText: some View {
        if !resolvedUnit.isEmpty {
            Text(resolvedUnit)
                .font(.title3.weight(.medium))
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // Static decoration never implies score progress and needs no motion fallback.
    private var lowDunes: some View {
        ZStack {
            MetricQuantityDune(isForeground: false)
                .fill(palette.gold.opacity(0.08))
            MetricQuantityDune(isForeground: true)
                .fill(palette.gold.opacity(0.12))
        }
        .frame(height: 60)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct MetricQuantityDune: Shape {
    let isForeground: Bool

    func path(in rect: CGRect) -> Path {
        let ridge: CGFloat = isForeground ? 0.72 : 0.44
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * ridge))
        path.addCurve(
            to: CGPoint(x: rect.width, y: rect.height * (isForeground ? 0.54 : 0.68)),
            control1: CGPoint(x: rect.width * 0.30, y: rect.height * (isForeground ? 0.96 : 0.06)),
            control2: CGPoint(x: rect.width * 0.62, y: rect.height * (isForeground ? 0.26 : 0.92))
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Preserve the route's actual measurement independently of history-series units.
/// Steps alone retains the existing configured ViewModel headline override.
enum MetricDetailHeadline {
    static func resolve(
        _ metric: HealthMetric, stepsValue: Double?, stepsUpdated: Date?
    ) -> HealthMetric {
        guard metric.category == .steps, let stepsValue else { return metric }
        return HealthMetric(
            id: metric.id, name: metric.name, value: stepsValue, unit: metric.unit,
            change: metric.change, date: stepsUpdated ?? metric.date, category: metric.category,
            isHistorical: metric.isHistorical, iconOverride: metric.iconOverride,
            workoutTypeKey: metric.workoutTypeKey
        )
    }
}

/// Shared only within Presentation: mirrors the legacy header, not HealthMetric.formattedNumericValue.
struct MetricDetailValueFormatter {
    let category: HealthMetric.Category
    var unitOverride: String? = nil

    var unit: String { unitOverride ?? category.unitLabel }

    func string(from value: Double) -> String {
        guard value.isFinite else { return "—" }
        // Preserve the legacy header's override precedence for every category.
        if unitOverride == "km" {
            return value.formattedWithSeparator(fractionDigits: 1)
        }
        switch category {
        case .hrv: return value.formattedWithSeparator()
        case .rhr: return value.formattedWithSeparator()
        case .heartRate: return value.formattedWithSeparator()
        case .sleep:
            // hoursMinutesFormatted converts to Int; finite but out-of-range values also trap.
            guard value >= Double(Int.min), value < Double(Int.max) else { return "—" }
            return value.hoursMinutesFormatted
        case .exercise: return value.formattedWithSeparator()
        case .steps: return value.formattedWithSeparator()
        case .weight: return value.formattedWithSeparator(fractionDigits: 1)
        case .bmi: return value.formattedWithSeparator(fractionDigits: 1)
        case .bodyFat: return value.formattedWithSeparator(fractionDigits: 1)
        case .leanBodyMass: return value.formattedWithSeparator(fractionDigits: 1)
        case .spo2:
            let percentage = value * 100
            guard percentage.isFinite else { return "—" }
            return percentage.formattedWithSeparator()
        case .respiratoryRate: return value.formattedWithSeparator()
        case .vo2Max: return value.formattedWithSeparator(fractionDigits: 1)
        case .heartRateRecovery: return value.formattedWithSeparator()
        case .wristTemperature: return value.formattedWithSeparator(fractionDigits: 1, alwaysShowSign: true)
        case .breathingDisturbances: return value.formattedWithSeparator(fractionDigits: 1)
        }
    }
}

#Preview("Raw HRV quantity") {
    ScrollView {
        MetricQuantityHero(metric: HealthMetric(
            id: "quantity-hero-preview", name: "HRV", value: 52, unit: "ms",
            change: nil, date: .now, category: .hrv
        ))
        .padding(DS.Spacing.lg)
    }
}
