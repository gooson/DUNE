import SwiftUI

/// In-session exercise reorder sheet for Watch.
/// Supports direct drag reorder and explicit up/down accessibility controls.
/// Completed exercises are pinned and cannot be moved.
struct WatchExerciseReorderView: View {
    @Environment(WorkoutManager.self) private var workoutManager

    var body: some View {
        List {
            if let snapshot = workoutManager.templateSnapshot {
                Section {
                    ForEach(Array(reorderSegments(for: snapshot).enumerated()), id: \.offset) { segmentIndex, segment in
                        switch segment {
                        case .completed(let index):
                            exerciseRow(snapshot.entries[index], at: index)
                        case .pending(let entries):
                            ForEach(entries) { entry in
                                if let index = snapshot.entries.firstIndex(where: { $0.id == entry.id }) {
                                    exerciseRow(entry, at: index)
                                }
                            }
                            .reorderable(collectionID: segmentIndex)
                        }
                    }
                } header: {
                    Text("Reorder Exercises")
                }
            }
        }
        .reorderContainer(for: TemplateEntry.self, in: Int.self) { difference in
            let destinationID: UUID?
            switch difference.destination.position {
            case .before(let id): destinationID = id
            case .end:
                let segments = workoutManager.templateSnapshot.map(reorderSegments(for:)) ?? []
                guard segments.indices.contains(difference.destination.collectionID) else { return }
                destinationID = segments.dropFirst(difference.destination.collectionID + 1).compactMap { segment in
                    if case .completed(let index) = segment {
                        return workoutManager.templateSnapshot?.entries[index].id
                    }
                    return nil
                }.first
            }
            workoutManager.reorderExercises(moving: difference.sources, before: destinationID)
        }
        .scrollContentBackground(.hidden)
        .background { WatchWaveBackground() }
    }

    private enum ReorderSegment {
        case completed(Int)
        case pending([TemplateEntry])
    }

    private func reorderSegments(for snapshot: WorkoutSessionTemplate) -> [ReorderSegment] {
        var segments: [ReorderSegment] = []
        var pending: [TemplateEntry] = []
        for (index, entry) in snapshot.entries.enumerated() {
            let isCompleted = index < workoutManager.completedSetsData.count
                && !workoutManager.completedSetsData[index].isEmpty
            if isCompleted {
                if !pending.isEmpty {
                    segments.append(.pending(pending))
                    pending = []
                }
                segments.append(.completed(index))
            } else {
                pending.append(entry)
            }
        }
        if !pending.isEmpty { segments.append(.pending(pending)) }
        return segments
    }

    private func exerciseRow(_ entry: TemplateEntry, at index: Int) -> some View {
        let isCompleted = index < workoutManager.completedSetsData.count
            && !workoutManager.completedSetsData[index].isEmpty
        let isCurrent = index == workoutManager.currentExerciseIndex

        return VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                EquipmentIconView(equipment: entry.equipment, size: 20)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Color.positive)
                        .frame(width: 18)
                } else if isCurrent {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(DS.Color.activity)
                        .frame(width: 18)
                } else {
                    Text("\(index + 1)")
                        .font(DS.Typography.metricLabel)
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                }

                Text(entry.exerciseName)
                    .font(DS.Typography.tileTitle)
                    .lineLimit(2)
            }
            .opacity(isCompleted ? 0.5 : 1.0)

            if !isCompleted {
                HStack(spacing: DS.Spacing.sm) {
                    Button {
                        workoutManager.moveExercise(at: index, direction: .up)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Move Up")
                    .accessibilityIdentifier("watch-reorder-up-\(index)")
                    .disabled(!workoutManager.canMoveExercise(at: index, direction: .up))

                    Button {
                        workoutManager.moveExercise(at: index, direction: .down)
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.caption2)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Move Down")
                    .accessibilityIdentifier("watch-reorder-down-\(index)")
                    .disabled(!workoutManager.canMoveExercise(at: index, direction: .down))
                }
            }
        }
    }
}
