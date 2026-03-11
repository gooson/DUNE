import SwiftUI
import SwiftData

/// Edit default weight/reps for a specific exercise.
/// Creates or updates ExerciseDefaultRecord in SwiftData (CloudKit synced).
struct ExerciseDefaultEditView: View {
    let exercise: ExerciseDefinition

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ExerciseDefaultRecord.lastUsedDate, order: .reverse)
    private var allDefaults: [ExerciseDefaultRecord]

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var isManualOverride: Bool = false
    @State private var isPreferred: Bool = false
    /// Correction #6/#11: Prevent duplicate saves on double-tap
    @State private var isSaving: Bool = false
    /// Correction #50: Confirmation before CloudKit delete
    @State private var showClearConfirmation: Bool = false

    private let maxWeightKg = 500.0
    private let maxReps = 1000
    private let library = ExerciseLibraryService.shared

    private var existingRecord: ExerciseDefaultRecord? {
        allDefaults.first { record in
            let representativeID = library.representativeExercise(byID: record.exerciseDefinitionID)?.id
                ?? record.exerciseDefinitionID
            return representativeID == exercise.id
        }
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

                Toggle(isOn: $isPreferred) {
                    Label("Preferred Exercise", systemImage: "star")
                }
            } header: {
                Text(exercise.localizedName)
            } footer: {
                Text("Manual override keeps your saved defaults. Preferred exercises stay near the top of Quick Start on iPhone and Apple Watch.")
            }

            if existingRecord != nil {
                Section {
                    Button("Clear Exercise Settings", role: .destructive) {
                        showClearConfirmation = true
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Exercise Default")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveDefaults()
                    dismiss()
                }
                .disabled(isSaving)
            }
        }
        .onAppear {
            loadExistingValues()
        }
        .confirmationDialog(
            "Clear saved exercise settings?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Exercise Settings", role: .destructive) {
                clearDefaults()
            }
        } message: {
            Text("This will remove the saved defaults and preferred status for \(exercise.localizedName). This change syncs across all your devices.")
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
        isPreferred = record.isPreferred
    }

    private func saveDefaults() {
        guard !isSaving else { return }
        isSaving = true

        // Parse weight (Correction #38: trim + isEmpty check)
        let trimmedWeight = weightText.trimmingCharacters(in: .whitespaces)
        let weight: Double? = if !trimmedWeight.isEmpty, let parsed = Double(trimmedWeight) {
            parsed > 0 ? Swift.min(parsed, maxWeightKg) : nil
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
        guard weight != nil || reps != nil || isManualOverride || isPreferred else {
            // Nothing to save; clear if existing
            if let record = existingRecord {
                withAnimation { modelContext.delete(record) }
            }
            WatchSessionManager.shared.syncExerciseLibraryToWatch()
            isSaving = false
            return
        }

        if let record = existingRecord {
            record.exerciseDefinitionID = exercise.id
            record.defaultWeight = weight
            record.defaultReps = reps
            record.isManualOverride = isManualOverride
            record.isPreferred = isPreferred
            record.lastUsedDate = Date()
        } else {
            let record = ExerciseDefaultRecord(
                exerciseDefinitionID: exercise.id,
                defaultWeight: weight,
                defaultReps: reps,
                isManualOverride: isManualOverride,
                isPreferred: isPreferred,
                lastUsedDate: Date()
            )
            modelContext.insert(record)
        }
        WatchSessionManager.shared.syncExerciseLibraryToWatch()
        isSaving = false
    }

    private func clearDefaults() {
        if let record = existingRecord {
            withAnimation { modelContext.delete(record) }
        }
        WatchSessionManager.shared.syncExerciseLibraryToWatch()
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
