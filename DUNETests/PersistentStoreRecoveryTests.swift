import Foundation
import Testing
import SwiftData
@testable import DUNE

@Suite("PersistentStoreRecovery")
struct PersistentStoreRecoveryTests {
    @Test("Opening a locked store exposes no writable runtime; retry returns records from the same store")
    @MainActor
    func retriesOriginalStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("exercise.store")
        let schema = Schema([ExerciseRecord.self, WorkoutSet.self])
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let expectedID: UUID
        do {
            let original = try ModelContainer(for: schema, configurations: configuration)
            let exercise = ExerciseRecord(date: .now, exerciseType: "Fixture", duration: 60)
            expectedID = exercise.id
            original.mainContext.insert(exercise)
            try original.mainContext.save()
        }
        let before = try Data(contentsOf: url)
        var locked = true
        func open() throws -> ModelContainer {
            if locked { throw CocoaError(.fileReadNoPermission) }
            return try ModelContainer(for: schema, configurations: configuration)
        }
        let blocked = PersistentStoreOpening(open: open)
        #expect(blocked.value == nil)
        #expect(try Data(contentsOf: url) == before)
        locked = false
        let reopened = try #require(PersistentStoreOpening(open: open).value)
        let records = try reopened.mainContext.fetch(FetchDescriptor<ExerciseRecord>())
        #expect(records.map(\.id) == [expectedID])
        #expect(reopened.configurations.allSatisfy { !$0.isStoredInMemoryOnly })
    }

    @Test("Recognizes staged migration model version errors")
    func recognizesMigrationCompatibilityErrors() {
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: 134504,
            userInfo: [
                NSLocalizedDescriptionKey: "Cannot use staged migration with an unknown coordinator model version."
            ]
        )

        #expect(PersistentStoreRecovery.isMigrationFailure(error))
    }

    @Test("Recognizes when migration failure is nested as underlying error")
    func recognizesNestedMigrationErrors() {
        let underlying = NSError(
            domain: NSCocoaErrorDomain,
            code: 134100,
            userInfo: [
                NSLocalizedDescriptionKey: "Persistent store incompatible version hash"
            ]
        )
        let topLevel = NSError(
            domain: "SwiftDataError",
            code: 1,
            userInfo: [NSUnderlyingErrorKey: underlying]
        )

        #expect(PersistentStoreRecovery.isMigrationFailure(topLevel))
    }

    @Test("Recognizes wrapped SwiftData loadIssueModelContainer errors")
    func recognizesWrappedSwiftDataLoadIssue() {
        let error = WrappedSwiftDataLoadIssueError()

        #expect(PersistentStoreRecovery.isMigrationFailure(error))
    }

    @Test("Does not classify as migration: non-migration startup failures")
    func doesNotClassifyNonMigrationFailures() {
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: 257,
            userInfo: [
                NSLocalizedDescriptionKey: "The file couldn’t be opened because you don’t have permission."
            ]
        )

        #expect(!PersistentStoreRecovery.isMigrationFailure(error))
    }

    @Test("Does not classify as migration: CloudKit/account availability errors")
    func doesNotClassifyCloudKitAvailabilityFailures() {
        let error = NSError(
            domain: "CKErrorDomain",
            code: 6,
            userInfo: [
                NSLocalizedDescriptionKey: "The operation couldn’t be completed because the account is unavailable."
            ]
        )

        #expect(!PersistentStoreRecovery.isMigrationFailure(error))
    }

    @Test("Does not classify as migration: other wrapped SwiftData errors")
    func doesNotClassifyOtherWrappedSwiftDataErrors() {
        let error = WrappedSwiftDataSaveIssueError()

        #expect(!PersistentStoreRecovery.isMigrationFailure(error))
    }
}

private struct WrappedSwiftDataLoadIssueError: Error, CustomStringConvertible, CustomDebugStringConvertible {
    let description = "SwiftData.SwiftDataError(_error: SwiftData.SwiftDataError._Error.loadIssueModelContainer, _explanation: nil)"
    let debugDescription = "SwiftData.SwiftDataError(_error: SwiftData.SwiftDataError._Error.loadIssueModelContainer, _explanation: nil)"
}

private struct WrappedSwiftDataSaveIssueError: Error, CustomStringConvertible, CustomDebugStringConvertible {
    let description = "SwiftData.SwiftDataError(_error: SwiftData.SwiftDataError._Error.saveIssueModelContext, _explanation: nil)"
    let debugDescription = "SwiftData.SwiftDataError(_error: SwiftData.SwiftDataError._Error.saveIssueModelContext, _explanation: nil)"
}
