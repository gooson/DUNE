import Foundation
import HealthKit
import Testing
@testable import DUNEWatch

@Suite("Watch workout authorization")
@MainActor
struct WorkoutManagerAuthorizationTests {
    @Test("Reading workout routes also requests their parent workout type")
    func routeReadIncludesWorkoutRead() {
        let types = WorkoutManager.authorizationReadTypes

        #expect(types.contains(HKSeriesType.workoutRoute()))
        #expect(types.contains(HKObjectType.workoutType()))
    }

    @Test("Sharing workout routes also requests their parent workout type")
    func routeShareIncludesWorkoutShare() {
        let types = WorkoutManager.authorizationShareTypes

        #expect(types.contains(HKSeriesType.workoutRoute()))
        #expect(types.contains(HKObjectType.workoutType()))
    }

    @Test("HealthKit accepts the workout authorization type dependencies", .timeLimit(.minutes(1)))
    func authorizationTypesPassHealthKitValidation() async throws {
        // Unlike requestAuthorization, this validates the actual types without showing a permission form.
        do {
            _ = try await HKHealthStore().statusForAuthorizationRequest(
                toShare: WorkoutManager.authorizationShareTypes,
                read: WorkoutManager.authorizationReadTypes
            )
        } catch {
#if targetEnvironment(simulator)
            // Unsigned simulator hosts can pass type validation but lack HealthKit entitlements.
            // Invalid route dependencies raise NSException before this recoverable error.
            let nsError = error as NSError
            guard nsError.domain == HKErrorDomain,
                  nsError.code == HKError.Code.errorAuthorizationDenied.rawValue,
                  nsError.localizedDescription.contains("Missing com.apple.developer.healthkit entitlement.") else {
                throw error
            }
#else
            throw error
#endif
        }
    }
}
