import Foundation
import SwiftData
import Testing
@testable import DUNE

@Suite("SimulatorAdvancedMockData")
@MainActor
struct SimulatorAdvancedMockDataTests {
    @Test("seed stores advanced mock dataset and persists reference date")
    func seedStoresDatasetAndReferenceDate() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

        clearMockMode()
        defer { clearMockMode() }

        try SimulatorAdvancedMockDataProvider.seed(into: context, referenceDate: referenceDate)

        #expect(SimulatorAdvancedMockDataModeStore.isEnabled)
        #expect(SimulatorAdvancedMockDataModeStore.referenceDate == referenceDate)

        let mirrorRecords = try context.fetch(FetchDescriptor<HealthSnapshotMirrorRecord>())
        let bodyRecords = try context.fetch(FetchDescriptor<BodyCompositionRecord>())
        let exerciseRecords = try context.fetch(FetchDescriptor<ExerciseRecord>())
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())

        #expect(mirrorRecords.count == 1)
        #expect(!bodyRecords.isEmpty)
        #expect(templates.count == 2)
        #expect(exerciseRecords.contains { $0.healthKitWorkoutID == "mock-workout-running-tempo" })

        let currentData = SimulatorAdvancedMockDataProvider.current(
            referenceDate: referenceDate.addingTimeInterval(60 * 60 * 24 * 14)
        )
        #expect(currentData?.referenceDate == referenceDate)
        #expect(currentData?.workouts.count == 10)
    }

    @Test("reset clears persisted simulator mock data")
    func resetClearsPersistedData() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        clearMockMode()
        defer { clearMockMode() }

        try SimulatorAdvancedMockDataProvider.seed(
            into: context,
            referenceDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try SimulatorAdvancedMockDataProvider.reset(into: context)

        #expect(!SimulatorAdvancedMockDataModeStore.isEnabled)
        #expect(SimulatorAdvancedMockDataModeStore.referenceDate == nil)
        #expect(try context.fetch(FetchDescriptor<HealthSnapshotMirrorRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ExerciseRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<BodyCompositionRecord>()).isEmpty)
    }

    @Test("query services resolve simulator mock data without HealthKit")
    func queryServicesResolveMockData() async throws {
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

        clearMockMode()
        defer { clearMockMode() }

        SimulatorAdvancedMockDataModeStore.setReferenceDate(referenceDate)
        SimulatorAdvancedMockDataModeStore.setEnabled(true)

        let workoutService = WorkoutQueryService(manager: .shared)
        let heartRateService = HeartRateQueryService(manager: .shared)
        let hrvService = HRVQueryService(manager: .shared)
        let sleepService = SleepQueryService(manager: .shared)
        let stepsService = StepsQueryService(manager: .shared)
        let bodyCompositionService = BodyCompositionQueryService(manager: .shared)
        let vitalsService = VitalsQueryService(manager: .shared)

        let workouts = try await workoutService.fetchWorkouts(days: 30)
        let heartRateSamples = try await heartRateService.fetchHeartRateSamples(
            forWorkoutID: "mock-workout-running-tempo"
        )
        let latestRHR = try await hrvService.fetchLatestRestingHeartRate(withinDays: 7)
        let latestSleep = try await sleepService.fetchLatestSleepStages(withinDays: 7)
        let latestSteps = try await stepsService.fetchLatestSteps(withinDays: 7)
        let latestWeight = try await bodyCompositionService.fetchLatestWeight(withinDays: 30)
        let latestVO2Max = try await vitalsService.fetchLatestVO2Max(withinDays: 30)

        #expect(workouts.count == 10)
        #expect(!heartRateSamples.isEmpty)
        #expect(latestRHR?.value == 50)
        #expect(latestSleep?.stages.isEmpty == false)
        #expect(latestSteps != nil)
        #expect(latestWeight != nil)
        #expect(latestVO2Max != nil)
    }

    @Test("cloud mirrored snapshot service returns simulator mock snapshot when enabled")
    func cloudMirroredServiceReturnsMockSnapshot() async throws {
        let container = try makeInMemoryContainer()
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

        clearMockMode()
        defer { clearMockMode() }

        SimulatorAdvancedMockDataModeStore.setReferenceDate(referenceDate)
        SimulatorAdvancedMockDataModeStore.setEnabled(true)

        let service = CloudMirroredSharedHealthDataService(
            modelContainer: container,
            cacheTTL: 60,
            nowProvider: { referenceDate.addingTimeInterval(60 * 60 * 24) }
        )

        let snapshot = await service.fetchSnapshot()

        #expect(snapshot.fetchedAt == referenceDate)
        #expect(snapshot.conditionScore?.score == 90)
        #expect(snapshot.hrvSamples.count == 30)
    }

    private func clearMockMode() {
        SimulatorAdvancedMockDataModeStore.setEnabled(false)
        SimulatorAdvancedMockDataModeStore.setReferenceDate(nil)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ExerciseRecord.self,
            BodyCompositionRecord.self,
            WorkoutSet.self,
            CustomExercise.self,
            WorkoutTemplate.self,
            UserCategory.self,
            HealthSnapshotMirrorRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
