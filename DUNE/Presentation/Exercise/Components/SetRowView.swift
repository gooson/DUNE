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

    private var showsAddedWeight: Bool { addedWeightEnabled || !editableSet.weight.isEmpty }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Set number + type indicator
            VStack(spacing: 0) {
                Text("\(editableSet.setNumber)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(editableSet.setType == .working ? .secondary : editableSet.setType.tintColor)
                if editableSet.setType != .working {
                    Text(editableSet.setType.displayName.prefix(1))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(editableSet.setType.tintColor)
                }
            }
            .frame(width: 24)

            // Previous set info (tap to fill)
            Button {
                onFillFromPrevious?()
            } label: {
                previousLabel
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 56, alignment: .leading)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .disabled(previousSet == nil || onFillFromPrevious == nil)

            // Input fields based on exercise type
            inputFields

            Spacer(minLength: 0)

            // Completion checkbox
            Button {
                onComplete()
            } label: {
                Image(systemName: editableSet.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(editableSet.isCompleted ? DS.Color.activity : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 28)
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
            HStack(spacing: DS.Spacing.xs) {
                TextField(weightUnit.displayName, text: $editableSet.weight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 70)
                    .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-weight")

                TextField("reps", text: $editableSet.reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 60)
                    .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-reps")
            }

        case .setsReps:
            HStack(spacing: DS.Spacing.xs) {
                if showsAddedWeight {
                    TextField(weightUnit.displayName, text: $editableSet.weight)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 70)
                        .accessibilityLabel("Added Weight")
                        .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-weight")
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
                    .frame(maxWidth: 70)
                    .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-reps")
            }

        case .durationDistance:
            HStack(spacing: DS.Spacing.xs) {
                TextField("min", text: $editableSet.duration)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 60)
                    .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-duration")

                let unit = cardioUnit ?? .km
                if unit != .timeOnly {
                    if unit.usesDistanceField {
                        TextField(unit.placeholder, text: $editableSet.distance)
                            .keyboardType(unit.keyboardType)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 70)
                            .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-distance")
                    } else if unit.usesRepsField {
                        TextField(unit.placeholder, text: $editableSet.reps)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 70)
                            .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-reps")

                        if unit == .floors {
                            TextField("lvl", text: $editableSet.level)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 56)
                                .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-level")
                        }
                    }
                }
            }

        case .durationIntensity:
            TextField("sec", text: $editableSet.duration)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 60)
                .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-duration")

        case .roundsBased:
            HStack(spacing: DS.Spacing.xs) {
                TextField("reps", text: $editableSet.reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 60)
                    .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-reps")

                TextField("sec", text: $editableSet.duration)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 60)
                    .accessibilityIdentifier("set-row-field-\(editableSet.setNumber)-duration")
            }
        }
    }
}
