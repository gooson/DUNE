import Foundation

enum PersistentStoreRecovery {
    private static let migrationErrorCodes: Set<Int> = [
        134100, // NSPersistentStoreIncompatibleVersionHashError
        134110, // NSMigrationError
        134130, // NSMigrationMissingSourceModelError
        134140, // NSMigrationMissingMappingModelError
        134150, // NSMigrationManagerSourceStoreError
        134160, // NSMigrationManagerDestinationStoreError
        134170, // NSEntityMigrationPolicyError
        134504, // SwiftData/Core Data staged migration unknown coordinator model version
    ]

    private static let migrationMessageSignatures = [
        "persistent store incompatible version hash",
        "unknown coordinator model version",
        "staged migration",
        "model version checksum",
        "duplicate version checksums",
        "incompatible version hash",
        "incompatible model",
        "mapping model",
        "missing source model",
        "missing mapping model"
    ]

    static func shouldDeleteStore(after error: Error) -> Bool {
        expandedNSErrorChain(from: error).contains(where: isRecoverableMigrationFailure)
    }

    private static func isRecoverableMigrationFailure(_ error: NSError) -> Bool {
        if migrationErrorCodes.contains(error.code) {
            return true
        }

        let message = normalizedErrorText(for: error)
        return migrationMessageSignatures.contains(where: message.contains)
    }

    private static func normalizedErrorText(for error: NSError) -> String {
        let components = [
            error.domain,
            error.localizedDescription,
            error.localizedFailureReason,
            error.localizedRecoverySuggestion,
            error.userInfo[NSDebugDescriptionErrorKey] as? String,
        ]

        return components
            .compactMap { $0?.lowercased() }
            .joined(separator: "\n")
    }

    private static func expandedNSErrorChain(from error: Error) -> [NSError] {
        var results: [NSError] = []
        var queue: [NSError] = [error as NSError]
        var visited = Set<ErrorFingerprint>()

        while let current = queue.popLast() {
            let fingerprint = ErrorFingerprint(domain: current.domain, code: current.code, description: current.localizedDescription)
            guard visited.insert(fingerprint).inserted else { continue }
            results.append(current)

            if let underlying = current.userInfo[NSUnderlyingErrorKey] as? NSError {
                queue.append(underlying)
            }

            if let detailed = current.userInfo["NSDetailedErrors"] as? [NSError] {
                queue.append(contentsOf: detailed)
            }
        }

        return results
    }
}

private struct ErrorFingerprint: Hashable {
    let domain: String
    let code: Int
    let description: String
}
