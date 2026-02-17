import SwiftUI

struct SetRowView: View {
    @Binding var editableSet: EditableSet
    let inputType: ExerciseInputType
    let previousSet: PreviousSetInfo?
    let weightUnit: WeightUnit
    let onComplete: () -> Void
    var onFillFromPrevious: (() -> Void)?

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

            // Completion checkbox
            Button {
                onComplete()
            } label: {
                Image(systemName: editableSet.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(editableSet.isCompleted ? DS.Color.activity : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.sm)
        .background(
            editableSet.isCompleted
                ? editableSet.setType.tintColor.opacity(0.08)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: DS.Radius.sm)
        )
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
                Text("×\(r)")
            case .durationDistance:
                let d = prev.duration.map { "\(Int($0 / 60))m" } ?? "—"
                let dist = prev.distance.map {
                    $0.formatted(.number.precision(.fractionLength(0...1))) + "k"
                } ?? ""
                Text(dist.isEmpty ? d : "\(d) \(dist)")
            case .durationIntensity:
                let d = prev.duration.map { "\(Int($0 / 60))m" } ?? "—"
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

                TextField("reps", text: $editableSet.reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 60)
            }

        case .setsReps:
            TextField("reps", text: $editableSet.reps)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 80)

        case .durationDistance:
            HStack(spacing: DS.Spacing.xs) {
                TextField("min", text: $editableSet.duration)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 60)

                TextField("km", text: $editableSet.distance)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 70)
            }

        case .durationIntensity:
            HStack(spacing: DS.Spacing.xs) {
                TextField("min", text: $editableSet.duration)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 60)

                TextField("1-10", text: $editableSet.intensity)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 60)
            }

        case .roundsBased:
            HStack(spacing: DS.Spacing.xs) {
                TextField("reps", text: $editableSet.reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 60)

                TextField("sec", text: $editableSet.duration)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 60)
            }
        }
    }
}
