import SwiftUI
import SwiftData
import UIKit

struct HealthQueryRecordDetailView: View {
    let snapshot: HealthQueryWorkoutSnapshot
    let queryService: any HealthQuerying
    @Environment(\.modelContext) private var modelContext
    @State private var manualRecord: ExerciseRecord?
    @State private var healthWorkout: WorkoutSummary?
    @State private var finishedLoading = false
    @State private var isLocked = false

    var body: some View {
        Group {
            if isLocked {
                ContentUnavailableView("Unlock your device to view health data.", systemImage: "lock")
            } else if let manualRecord {
                ExerciseSessionDetailView(record: manualRecord, activityType: snapshot.activityType ?? .other,
                                          displayName: snapshot.name)
            } else if let healthWorkout {
                HealthKitWorkoutDetailView(workout: healthWorkout)
            } else if finishedLoading {
                ContentUnavailableView("Record no longer available", systemImage: "tray")
            } else {
                ProgressView("Opening record...")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
            manualRecord = nil
            healthWorkout = nil
            isLocked = true
        }
        .task(id: snapshot.id) {
            guard UIApplication.shared.isProtectedDataAvailable else { isLocked = true; return }
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: snapshot.date)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
            let end = min(Date(), nextDay)
            guard end > start else { finishedLoading = true; return }
            let approvalRequest = HealthQueryRequest(kind: .latestWorkout,
                interval: DateInterval(start: start, end: end), workoutID: snapshot.id)
            guard let approval = try? await queryService.execute(approvalRequest),
                  approval.status == .available || approval.status == .partial,
                  approval.records.contains(where: { $0.id == snapshot.id }),
                  !Task.isCancelled, UIApplication.shared.isProtectedDataAvailable else {
                finishedLoading = true
                return
            }
            var resolvedManual: ExerciseRecord?
            var resolvedHealth: WorkoutSummary?
            if let localID = snapshot.localRecordID {
                let descriptor = FetchDescriptor<ExerciseRecord>(predicate: #Predicate { $0.id == localID })
                resolvedManual = try? modelContext.fetch(descriptor).first
            }
            if resolvedManual == nil, let workoutID = snapshot.healthKitWorkoutID {
                let workouts = try? await WorkoutQueryService(manager: .shared).fetchWorkouts(start: start, end: end)
                resolvedHealth = workouts?.first { $0.id == workoutID }
            }
            guard let refreshed = try? await queryService.execute(approvalRequest),
                  refreshed.status == .available || refreshed.status == .partial,
                  refreshed.records.contains(where: { $0.id == snapshot.id }),
                  !Task.isCancelled, UIApplication.shared.isProtectedDataAvailable else {
                finishedLoading = true
                return
            }
            manualRecord = resolvedManual
            healthWorkout = resolvedHealth
            finishedLoading = true
        }
    }
}

