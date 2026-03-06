import Foundation
import Testing
@testable import DUNE

@Suite("PersistentStoreRecovery")
struct PersistentStoreRecoveryTests {
    @Test("Deletes store for staged migration model version errors")
    func deletesStoreForMigrationCompatibilityErrors() {
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: 134504,
            userInfo: [
                NSLocalizedDescriptionKey: "Cannot use staged migration with an unknown coordinator model version."
            ]
        )

        #expect(PersistentStoreRecovery.shouldDeleteStore(after: error))
    }

    @Test("Deletes store when migration failure is nested as underlying error")
    func deletesStoreForNestedMigrationErrors() {
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

        #expect(PersistentStoreRecovery.shouldDeleteStore(after: topLevel))
    }

    @Test("Keeps store for non-migration startup failures")
    func keepsStoreForNonMigrationFailures() {
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: 257,
            userInfo: [
                NSLocalizedDescriptionKey: "The file couldn’t be opened because you don’t have permission."
            ]
        )

        #expect(!PersistentStoreRecovery.shouldDeleteStore(after: error))
    }

    @Test("Keeps store for CloudKit/account availability errors")
    func keepsStoreForCloudKitAvailabilityFailures() {
        let error = NSError(
            domain: "CKErrorDomain",
            code: 6,
            userInfo: [
                NSLocalizedDescriptionKey: "The operation couldn’t be completed because the account is unavailable."
            ]
        )

        #expect(!PersistentStoreRecovery.shouldDeleteStore(after: error))
    }
}
