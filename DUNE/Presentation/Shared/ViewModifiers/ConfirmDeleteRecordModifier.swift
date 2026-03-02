import SwiftUI
import SwiftData

struct ConfirmDeleteRecordModifier: ViewModifier {
    @Binding var recordToDelete: ExerciseRecord?
    let modelContext: ModelContext

    func body(content: Content) -> some View {
        content
            .alert(
                "Delete Exercise?",
                isPresented: Binding(
                    get: { recordToDelete != nil },
                    set: { if !$0 { recordToDelete = nil } }
                ),
                presenting: recordToDelete
            ) { record in
                Button("Delete", role: .destructive) {
                    // Guard against stale reference (record may have been deleted via CloudKit sync)
                    guard record.modelContext != nil else {
                        recordToDelete = nil
                        return
                    }
                    // Capture HK ID before SwiftData delete invalidates the record
                    let hkWorkoutID = record.healthKitWorkoutID
                    let recordDate = record.date
                    let inferredActivityType =
                        WorkoutActivityType.infer(from: record.exerciseType)
                        ?? (record.hasSetData ? .traditionalStrengthTraining : nil)

                    // SwiftData delete first (authoritative action).
                    // Wrap in withAnimation so List/ForEach can properly diff the collection change.
                    // Without this, @Query fires synchronously and the UICollectionView count
                    // mismatches its internal state, causing NSInternalInconsistencyException.
                    withAnimation {
                        modelContext.delete(record)
                        recordToDelete = nil
                    }

                    // HealthKit cleanup as side-effect (fire-and-forget)
                    Task { @MainActor in
                        let deleteService = WorkoutDeleteService(manager: .shared)
                        do {
                            guard let targetUUID = try await deleteService.resolveDeletionTargetUUID(
                                linkedUUID: hkWorkoutID,
                                fallbackStartDate: recordDate,
                                preferredActivityType: inferredActivityType
                            ) else {
                                return
                            }

                            do {
                                try await deleteService.deleteWorkout(uuid: targetUUID)
                            } catch {
                                AppLogger.healthKit.error(
                                    "iPhone workout delete failed for \(targetUUID, privacy: .public): \(error.localizedDescription)"
                                )
                                WatchSessionManager.shared.requestWatchWorkoutDeletion(workoutUUID: targetUUID)
                            }
                        } catch {
                            AppLogger.healthKit.error("Failed to resolve workout deletion target: \(error.localizedDescription)")
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    recordToDelete = nil
                }
            } message: { record in
                Text("\(record.exerciseType) on \(record.date.formatted(date: .abbreviated, time: .omitted)) will be permanently deleted from all your devices.")
            }
    }
}

extension View {
    func confirmDeleteRecord(_ record: Binding<ExerciseRecord?>, context: ModelContext) -> some View {
        modifier(ConfirmDeleteRecordModifier(recordToDelete: record, modelContext: context))
    }
}
