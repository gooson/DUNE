import SwiftUI

/// Optional, descriptive comparison with explicitly selected US survey cohorts.
/// Integration: pass the current HealthMetric used by MetricDetailView's hero.
struct BodyPeerComparisonCard: View {
    let metric: HealthMetric

    @AppStorage("bodyPeerReference.ageGroup") private var ageGroupRaw = ""
    @AppStorage("bodyPeerReference.surveySex") private var surveySexRaw = ""
    @State private var isChoosingCriteria = false
    @State private var isShowingSource = false
    @State private var draftAgeGroup: BodyPeerReference.AgeGroup?
    @State private var draftSurveySex: BodyPeerReference.SurveySex?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var rowIconWidth: CGFloat = 24

    private var criteria: BodyPeerReference.Criteria? {
        BodyPeerReference.Criteria(ageGroupRawValue: ageGroupRaw, sexRawValue: surveySexRaw)
    }

    private var referenceMetric: BodyPeerReference.Metric? {
        switch metric.category {
        case .weight: .weight
        case .bmi: .bmi
        default: nil
        }
    }

    /// Weight HealthMetric.value is expressed by HealthMetric.unit, never assumed to be kg.
    private var canonicalValue: Double? {
        switch metric.category {
        case .weight:
            guard let inputUnit = WeightUnit(rawValue: metric.unit) else { return nil }
            return inputUnit.toKg(metric.value)
        case .bmi:
            guard metric.unit.isEmpty else { return nil }
            return metric.value
        default:
            return nil
        }
    }

    private var bodyFatDisplay: BodyFatSurveyReference.Display? {
        guard metric.category == .bodyFat, metric.unit == "%", let criteria else { return nil }
        // Invalid readings use bodyFatContent's explicit unavailable state.
        return try? BodyFatSurveyReference.display(recordedPercent: metric.value, criteria: criteria)
    }

    private var comparison: BodyPeerReference.Comparison? {
        guard let referenceMetric, let criteria, let canonicalValue else { return nil }
        // Invalid or out-of-range measurements have an expected unavailable state.
        return try? BodyPeerReference.compare(
            canonicalValue: canonicalValue,
            metric: referenceMetric,
            criteria: criteria
        )
    }

    private var displayWeightUnit: WeightUnit? {
        guard metric.category == .weight else { return nil }
        return WeightUnit(rawValue: metric.unit)
    }

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    Image(systemName: metric.resolvedIconName)
                        .foregroundStyle(metric.category.themeColor)
                        .accessibilityHidden(true)
                    if metric.category == .bodyFat {
                        Text("US DXA survey mean")
                            .font(DS.Typography.sectionTitle)
                    } else {
                        Text("US survey mean")
                            .font(DS.Typography.sectionTitle)
                    }
                    Spacer(minLength: DS.Spacing.sm)
                }

                switch metric.category {
                case .weight, .bmi:
                    supportedContent
                case .bodyFat:
                    bodyFatContent
                case .leanBodyMass:
                    Text("A comparable survey mean is not available for this measure.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                default:
                    Text("Survey comparison is not available for this measure.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if referenceMetric != nil || metric.category == .bodyFat {
                    Button("View survey source") { isShowingSource = true }
                        .font(.footnote)
                        .frame(minHeight: 44, alignment: .leading)
                        .accessibilityIdentifier("body-peer-source")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("body-peer-card")
        .sheet(isPresented: $isChoosingCriteria) { criteriaSheet }
        .sheet(isPresented: $isShowingSource) { sourceSheet }
    }

    @ViewBuilder
    private var supportedContent: some View {
        if let comparison {
            comparisonContent(comparison)
        } else if criteria == nil {
            Text("Choose a survey age group and sex to compare values.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if canonicalValue == nil {
            Text("This measurement's unit cannot be compared with the survey.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("This measurement cannot be compared with the survey.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        Button {
            draftAgeGroup = criteria?.ageGroup
            draftSurveySex = criteria?.sex
            isChoosingCriteria = true
        } label: {
            if criteria == nil {
                Text("Choose comparison group")
            } else {
                Text("Change comparison group")
            }
        }
        .frame(minHeight: 44, alignment: .leading)
        .accessibilityIdentifier("body-peer-criteria-cta")
    }

    @ViewBuilder
    private var bodyFatContent: some View {
        if let criteria, let bodyFatDisplay {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("US adults · 1999–2004 · whole-body DXA")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Survey age group")
                        .foregroundStyle(.secondary)
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(BodyFatSurveyReference.broadAgeGroup(for: criteria.ageGroup).displayName)
                            Text(criteria.sex.displayName)
                        }
                    } else {
                        HStack(spacing: DS.Spacing.xs) {
                            Text(BodyFatSurveyReference.broadAgeGroup(for: criteria.ageGroup).displayName)
                            Text(verbatim: "·")
                            Text(criteria.sex.displayName)
                        }
                    }
                }
                .font(.subheadline)
                .accessibilityIdentifier("body-peer-selected-criteria")
                Text("Your measurement method may be unknown or different. DXA and bioimpedance estimates can differ; these values are not directly equivalent or a health assessment.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("body-fat-method-warning")
                surveyValue(label: "Your recorded body fat", value: bodyFatDisplay.recordedPercent,
                            identifier: "body-fat-recorded-value")
                surveyValue(label: "US DXA survey mean", value: bodyFatDisplay.reference.meanPercent,
                            identifier: "body-fat-survey-mean")
            }
        } else if criteria == nil {
            Text("Choose a survey age group and sex to view the US DXA mean.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("This recorded body-fat value is unavailable for the survey display.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        Button {
            draftAgeGroup = criteria?.ageGroup
            draftSurveySex = criteria?.sex
            isChoosingCriteria = true
        } label: {
            if criteria == nil {
                Text("Choose survey group")
            } else {
                Text("Change survey group")
            }
        }
        .frame(minHeight: 44, alignment: .leading)
        .accessibilityIdentifier("body-peer-criteria-cta")
    }

    private func surveyValue(label: LocalizedStringKey, value: Double, identifier: String) -> some View {
        iconRow {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(label)
                    .foregroundStyle(.secondary)
                Text(verbatim: "\(value.formattedWithSeparator(fractionDigits: 1))%")
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func comparisonContent(_ comparison: BodyPeerReference.Comparison) -> some View {
        let current = displayValue(comparison.currentValue)
        let mean = displayValue(comparison.reference.mean)
        let difference = displayValue(comparison.difference, signed: true)
        let unit = displayWeightUnit?.displayName ?? ""
        let maxValue = max(comparison.currentValue, comparison.reference.mean)

        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("US adults, 2021–2023 · mean")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: DS.Spacing.xs) {
                Text(comparison.reference.criteria.ageGroup.displayName)
                Text(verbatim: "·")
                Text(comparison.reference.criteria.sex.displayName)
            }
            .font(.subheadline)
            .accessibilityIdentifier("body-peer-selected-criteria")

            valueBar(label: "Current", value: current, unit: unit,
                     fraction: comparison.currentValue / maxValue,
                     tint: metric.category.themeColor,
                     identifier: "body-peer-current")
            valueBar(label: "Survey mean", value: mean, unit: unit,
                     fraction: comparison.reference.mean / maxValue,
                     tint: DS.Color.textSecondary,
                     identifier: "body-peer-reference")

            iconRow {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Difference (current − mean)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(unit.isEmpty ? difference : "\(difference) \(unit)")
                        .font(.subheadline.monospacedDigit())
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("body-peer-difference")
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func valueBar(
        label: LocalizedStringKey,
        value: String,
        unit: String,
        fraction: Double,
        tint: Color,
        identifier: String
    ) -> some View {
        iconRow {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(label).foregroundStyle(.secondary)
                    Text(unit.isEmpty ? value : "\(value) \(unit)")
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                GeometryReader { geometry in
                    Capsule()
                        .fill(tint.opacity(DS.Opacity.overlay))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(tint)
                                .frame(width: geometry.size.width * fraction)
                        }
                }
                .frame(height: DS.Spacing.md)
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func iconRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                rowIcon
                content()
            }
        } else {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                rowIcon
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var rowIcon: some View {
        Image(systemName: metric.resolvedIconName)
            .foregroundStyle(metric.category.themeColor)
            .frame(width: rowIconWidth, alignment: .leading)
            .accessibilityHidden(true)
    }

    private func displayValue(_ canonical: Double, signed: Bool = false) -> String {
        let displayed = displayWeightUnit?.fromKg(canonical) ?? canonical
        if signed, abs(displayed) < 0.05 {
            return (0.0 as Double).formattedWithSeparator(fractionDigits: 1)
        }
        return displayed.formattedWithSeparator(fractionDigits: 1, alwaysShowSign: signed)
    }

    private var criteriaSheet: some View {
        NavigationStack {
            Form {
                Section {
                    if metric.category == .bodyFat {
                        Text("This group shows US adult whole-body DXA survey means from 1999–2004. Your selected age maps to the survey's broader age group. It is not a Korean reference or a health target.")
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("This comparison uses US adult survey means from 2021–2023. It does not describe a Korean population or a health target.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Section("Survey group") {
                    if metric.category == .bodyFat && dynamicTypeSize.isAccessibilitySize {
                        Menu {
                            Button("Select age group") { draftAgeGroup = nil }
                            ForEach(BodyPeerReference.AgeGroup.allCases, id: \.self) { age in
                                Button(age.displayName) { draftAgeGroup = age }
                            }
                        } label: {
                            criteriaMenuLabel("Age at measurement", value: draftAgeGroup?.displayName ?? String(localized: "Select age group"))
                        }
                        .accessibilityIdentifier("body-peer-age-selection")
                        Menu {
                            Button("Select survey sex") { draftSurveySex = nil }
                            ForEach(BodyPeerReference.SurveySex.allCases, id: \.self) { sex in
                                Button(sex.displayName) { draftSurveySex = sex }
                            }
                        } label: {
                            criteriaMenuLabel("Sex in survey table", value: draftSurveySex?.displayName ?? String(localized: "Select survey sex"))
                        }
                        .accessibilityIdentifier("body-peer-sex-selection")
                    } else {
                        Picker("Age at measurement", selection: $draftAgeGroup) {
                            Text("Select age group").tag(nil as BodyPeerReference.AgeGroup?)
                            ForEach(BodyPeerReference.AgeGroup.allCases, id: \.self) { age in
                                Text(age.displayName).tag(Optional(age))
                            }
                        }
                        .accessibilityIdentifier("body-peer-age-selection")
                        Picker("Sex in survey table", selection: $draftSurveySex) {
                            Text("Select survey sex").tag(nil as BodyPeerReference.SurveySex?)
                            ForEach(BodyPeerReference.SurveySex.allCases, id: \.self) { sex in
                                Text(sex.displayName).tag(Optional(sex))
                            }
                        }
                        .accessibilityIdentifier("body-peer-sex-selection")
                    }
                }
                Section {
                    Text("The survey excludes pregnant women. Choose a group only when that reference applies to the measurement date.")
                        .font(.footnote)
                }
            }
            .englishNavigationTitle("Comparison group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isChoosingCriteria = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply group") {
                        guard let draftAgeGroup, let draftSurveySex else { return }
                        ageGroupRaw = draftAgeGroup.rawValue
                        surveySexRaw = draftSurveySex.rawValue
                        isChoosingCriteria = false
                    }
                    .disabled(draftAgeGroup == nil || draftSurveySex == nil)
                    .accessibilityIdentifier("body-peer-apply")
                }
            }
        }
        .presentationBackground(DS.Color.surfacePrimary)
    }

    private func criteriaMenuLabel(_ title: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .center, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(value)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DS.Spacing.sm)
            Image(systemName: "chevron.up.chevron.down")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var sourceSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if metric.category == .bodyFat {
                        Text(verbatim: "CDC/NCHS · \(BodyFatSurveyReference.reportIdentifier)")
                            .font(.headline)
                        Text("NHANES 1999–2004, US adults, whole-body DXA. Table 3 reports weighted mean percent body fat by broad age group and survey sex. These are not medians, percentiles or health targets.")
                        Text("DXA and other body-fat methods can give different results. The survey excluded pregnant people and people with certain equipment or recent contrast exposure; missing DXA data were statistically imputed. The mean is not an individual assessment.")
                        Text("The CDC/NCHS report is public domain and available free. CDC and NCHS do not endorse this app.")
                        Link("Open free original report", destination: BodyFatSurveyReference.sourcePDFURL)
                            .frame(minHeight: 44, alignment: .leading)
                    } else {
                        Text(verbatim: "CDC/NCHS · \(BodyPeerReference.reportIdentifier)")
                            .font(.headline)
                        Text("NHANES, August 2021–August 2023. US civilian noninstitutionalized adults; pregnant women excluded. Table 3: measured weight. Table 10: BMI. Values shown are means, not medians or health targets.")
                        Text("The report is public domain and the original is available free from CDC. CDC and NCHS do not endorse this app.")
                        Link("Open free original report", destination: BodyPeerReference.sourcePDFURL)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.xl)
            }
            .englishNavigationTitle("Survey source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isShowingSource = false }
                }
            }
        }
        .presentationBackground(DS.Color.surfacePrimary)
    }
}

private extension BodyPeerReference.AgeGroup {
    var displayName: String {
        switch self {
        case .twenties: String(localized: "20–29 years")
        case .thirties: String(localized: "30–39 years")
        case .forties: String(localized: "40–49 years")
        case .fifties: String(localized: "50–59 years")
        case .sixties: String(localized: "60–69 years")
        case .seventies: String(localized: "70–79 years")
        case .eightyAndOlder: String(localized: "80 years and older")
        }
    }
}

private extension BodyPeerReference.SurveySex {
    var displayName: String {
        switch self {
        case .male: String(localized: "Male (survey)")
        case .female: String(localized: "Female (survey)")
        }
    }
}

private extension BodyFatSurveyReference.AgeGroup {
    var displayName: String {
        switch self {
        case .twentyToThirtyNine: String(localized: "20–39 years")
        case .fortyToFiftyNine: String(localized: "40–59 years")
        case .sixtyToSeventyNine: String(localized: "60–79 years")
        case .eightyAndOlder: String(localized: "80 years and older")
        }
    }
}
