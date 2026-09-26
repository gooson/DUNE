import SwiftUI

struct SetRowView: View {
    @Binding var editableSet: EditableSet
    let inputType: ExerciseInputType
    let previousSet: PreviousSetInfo?
    let weightUnit: WeightUnit
    let cardioUnit: CardioSecondaryUnit?
    let onComplete: () -> Void
    var onFillFromPrevious: (() -> Void)?
    @State private var addedWeightEnabled = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }
    private var rowLayout: AnyLayout {
        isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
    }
    private var fieldLayout: AnyLayout {
        isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.xs))
    }

    private var showsAddedWeight: Bool { addedWeightEnabled || !editableSet.weight.isEmpty }

    var body: some View {
        rowLayout {
            // Set number + type indicator
            VStack(spacing: 0) {
                if isAccessibilitySize {
                    Text("SET")
                        .font(.caption)
                }
                Text("\(editableSet.setNumber)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(editableSet.setType == .working ? .secondary : editableSet.setType.tintColor)
                if editableSet.setType != .working {
                    Text(editableSet.setType.displayName.prefix(1))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(editableSet.setType.tintColor)
                }
            }
            .frame(width: isAccessibilitySize ? nil : 24)

            // Previous set info (tap to fill)
            Button {
                onFillFromPrevious?()
            } label: {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    if isAccessibilitySize { Text("PREV") }
                    previousLabel
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: isAccessibilitySize ? nil : 56, alignment: .leading)
                .lineLimit(isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: false, vertical: isAccessibilitySize)
            }
            .buttonStyle(.plain)
            .disabled(previousSet == nil || onFillFromPrevious == nil)

            // Input fields based on exercise type
            inputFields

            if !isAccessibilitySize { Spacer(minLength: 0) }

            // Completion checkbox
            Button {
                onComplete()
            } label: {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Image(systemName: editableSet.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(editableSet.isCompleted ? DS.Color.activity : .secondary)
                    if isAccessibilitySize {
                        Text("Complete Set")
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(width: isAccessibilitySize ? nil : 28)
            .accessibilityIdentifier("set-row-complete-\(editableSet.setNumber)")
        }
        .padding(.vertical, DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.sm)
        .background(
            editableSet.isCompleted
                ? editableSet.setType.tintColor.opacity(0.08)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: DS.Radius.sm)
        )
        .onChange(of: editableSet.weight, initial: true) { _, weight in
            if !weight.isEmpty { addedWeightEnabled = true }
        }
        .onChange(of: editableSet.id) { _, _ in
            addedWeightEnabled = !editableSet.weight.isEmpty
        }
    }

    @ViewBuilder
    private var previousLabel: some View {
        if let prev = previousSet {
            switch inputType {
            case .setsRepsWeight:
                let w = prev.weight.map {
                    weightUnit.fromKg($0).formatted(.number.precision(.fractionLength(0...1)))
                } ?? "—"
                let r = prev.reps.map { "\($0)" } ?? "—"
                Text("\(w)×\(r)")
            case .setsReps:
                let r = prev.reps.map { "\($0)" } ?? "—"
                if let weight = prev.weight, weight > 0 {
                    let w = weightUnit.fromKg(weight).formatted(.number.precision(.fractionLength(0...1)))
                    Text("\(w)×\(r)")
                } else {
                    Text("×\(r)")
                }
            case .durationDistance:
                let unit = cardioUnit ?? .km
                let d = prev.duration.map { "\(Int($0 / 60).formattedWithSeparator)m" } ?? "—"
                let suffix = unit.previousSuffix
                let secondary: String = {
                    if unit.usesRepsField {
                        let base = prev.reps.map { "\($0)\(suffix)" } ?? ""
                        if unit == .floors, let level = prev.intensity {
                            return base.isEmpty ? "L\(level)" : "\(base) L\(level)"
                        }
                        return base
                    } else if unit.usesDistanceField {
                        // Convert stored km back to display unit
                        let displayValue: Double? = switch unit {
                        case .meters: prev.distance.map { $0 * 1000 }
                        default: prev.distance
                        }
                        return displayValue.map {
                            $0.formatted(.number.precision(.fractionLength(0...1))) + suffix
                        } ?? ""
                    }
                    return ""
                }()
                Text(secondary.isEmpty ? d : "\(d) \(secondary)")
            case .durationIntensity:
                let d = prev.duration.map { "\(Int($0).formattedWithSeparator)s" } ?? "—"
                Text(d)
            case .roundsBased:
                let r = prev.reps.map { "\($0)r" } ?? "—"
                Text(r)
            }
        } else {
            Text("—")
        }
    }

    @ViewBuilder
    private var inputFields: some View {
        switch inputType {
        case .setsRepsWeight:
            fieldLayout {
                TextField(weightUnit.displayName, text: $editableSet.weight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-weight")
                    .modifier(SetInputFieldLayout(title: Text(weightUnit.displayName), compactWidth: 70))

                TextField("reps", text: $editableSet.reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-reps")
                    .modifier(SetInputFieldLayout(title: Text("reps"), compactWidth: 60))
            }

        case .setsReps:
            fieldLayout {
                if showsAddedWeight {
                    TextField(weightUnit.displayName, text: $editableSet.weight)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Added Weight")
                        .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-weight")
                        .modifier(SetInputFieldLayout(title: Text(weightUnit.displayName), compactWidth: 70))
                }
                Button {
                    if showsAddedWeight {
                        addedWeightEnabled = false
                        editableSet.weight = ""
                    } else {
                        addedWeightEnabled = true
                    }
                } label: {
                    Image(systemName: showsAddedWeight ? "minus.circle" : "plus.circle")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showsAddedWeight ? String(localized: "Remove Weight") : String(localized: "Add Weight"))
                .accessibilityIdentifier("set-row-toggle-weight-\(editableSet.setNumber)")

                TextField("reps", text: $editableSet.reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-reps")
                    .modifier(SetInputFieldLayout(title: Text("reps"), compactWidth: 70))
            }

        case .durationDistance:
            fieldLayout {
                TextField("min", text: $editableSet.duration)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-duration")
                    .modifier(SetInputFieldLayout(title: Text("min"), compactWidth: 60))

                let unit = cardioUnit ?? .km
                if unit != .timeOnly {
                    if unit.usesDistanceField {
                        TextField(unit.placeholder, text: $editableSet.distance)
                            .keyboardType(unit.keyboardType)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-distance")
                            .modifier(SetInputFieldLayout(title: Text(unit.placeholder), compactWidth: 70))
                    } else if unit.usesRepsField {
                        TextField(unit.placeholder, text: $editableSet.reps)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-reps")
                            .modifier(SetInputFieldLayout(title: Text(unit.placeholder), compactWidth: 70))

                        if unit == .floors {
                            TextField("lvl", text: $editableSet.level)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-level")
                                .modifier(SetInputFieldLayout(title: Text("lvl"), compactWidth: 56))
                        }
                    }
                }
            }

        case .durationIntensity:
            TextField("sec", text: $editableSet.duration)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-duration")
                .modifier(SetInputFieldLayout(title: Text("sec"), compactWidth: 60))

        case .roundsBased:
            fieldLayout {
                TextField("reps", text: $editableSet.reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-reps")
                    .modifier(SetInputFieldLayout(title: Text("reps"), compactWidth: 60))

                TextField("sec", text: $editableSet.duration)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-duration")
                    .modifier(SetInputFieldLayout(title: Text("sec"), compactWidth: 60))
            }
        }
    }
}

private struct SetInputFieldLayout: ViewModifier {
    let title: Text
    let compactWidth: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                title
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                content.frame(maxWidth: .infinity)
            }
        } else {
            content.frame(maxWidth: compactWidth)
        }
    }
}
