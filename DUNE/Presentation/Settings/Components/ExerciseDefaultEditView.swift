import SwiftUI
import SwiftData

/// Edit default weight/reps for a specific exercise.
/// Creates or updates ExerciseDefaultRecord in SwiftData (CloudKit synced).
struct ExerciseDefaultEditView: View {
    let exercise: ExerciseDefinition

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var allDefaults: [ExerciseDefaultRecord]

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var isManualOverride: Bool = false

    private let maxWeightKg = 500.0
    private let maxReps = 1000

    init(exercise: ExerciseDefinition) {
        self.exercise = exercise
        let exerciseID = exercise.id
        _allDefaults = Query(
            filter: #Predicate<ExerciseDefaultRecord> {
                $0.exerciseDefinitionID == exerciseID
            }
        )
    }

    private var existingRecord: ExerciseDefaultRecord? {
        allDefaults.first
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Label("Default Weight", systemImage: "scalemass")
                    Spacer()
                    TextField("kg", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                if exercise.inputType == .setsRepsWeight || exercise.inputType == .setsReps {
                    HStack {
                        Label("Default Reps", systemImage: "repeat")
                        Spacer()
                        TextField("reps", text: $repsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Toggle(isOn: $isManualOverride) {
                    Label("Manual Override", systemImage: "pin")
                }
            } header: {
                Text(exercise.localizedName)
            } footer: {
                Text("When enabled, this weight is always used instead of the last-used weight.")
            }

            if existingRecord != nil {
                Section {
                    Button("Clear Defaults", role: .destructive) {
                        clearDefaults()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { DetailWaveBackground() }
        .navigationTitle("Exercise Default")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveDefaults()
                    dismiss()
                }
            }
        }
        .onAppear {
            loadExistingValues()
        }
    }

    // MARK: - Data

    private func loadExistingValues() {
        guard let record = existingRecord else { return }
        if let weight = record.defaultWeight {
            weightText = weight.formatted(.number.precision(.fractionLength(0...1)))
        }
        if let reps = record.defaultReps {
            repsText = "\(reps)"
        }
        isManualOverride = record.isManualOverride
    }

    private func saveDefaults() {
        // Parse weight (Correction #38: trim + isEmpty check)
        let trimmedWeight = weightText.trimmingCharacters(in: .whitespaces)
        let weight: Double? = if !trimmedWeight.isEmpty, let parsed = Double(trimmedWeight) {
            Swift.min(Swift.max(parsed, 0), maxWeightKg)
        } else {
            nil
        }

        // Parse reps
        let trimmedReps = repsText.trimmingCharacters(in: .whitespaces)
        let reps: Int? = if !trimmedReps.isEmpty, let parsed = Int(trimmedReps) {
            Swift.min(Swift.max(parsed, 0), maxReps)
        } else {
            nil
        }

        // Skip save if both are nil and no manual override
        guard weight != nil || reps != nil || isManualOverride else {
            // Nothing to save; clear if existing
            if let record = existingRecord {
                withAnimation { modelContext.delete(record) }
            }
            return
        }

        if let record = existingRecord {
            record.defaultWeight = weight
            record.defaultReps = reps
            record.isManualOverride = isManualOverride
            record.lastUsedDate = Date()
        } else {
            let record = ExerciseDefaultRecord(
                exerciseDefinitionID: exercise.id,
                defaultWeight: weight,
                defaultReps: reps,
                isManualOverride: isManualOverride,
                lastUsedDate: Date()
            )
            modelContext.insert(record)
        }
    }

    private func clearDefaults() {
        if let record = existingRecord {
            withAnimation { modelContext.delete(record) }
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ExerciseDefaultEditView(
            exercise: ExerciseDefinition(
                id: "bench-press",
                name: "Bench Press",
                localizedName: "Bench Press",
                category: .strength,
                inputType: .setsRepsWeight,
                primaryMuscles: [.chest],
                secondaryMuscles: [.triceps, .shoulders],
                equipment: .barbell,
                metValue: 6.0
            )
        )
    }
}
