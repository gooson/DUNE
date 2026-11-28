import Foundation
import SwiftData

enum VisionExerciseHistoryContainerFactory {
    static let storeName = "VisionExerciseHistory"
    static let storeFilename = "vision-exercise-history.store"
    static let schema = Schema([ExerciseRecord.self, WorkoutSet.self])

    static func configuration(
        url: URL? = nil
    ) -> ModelConfiguration {
        ModelConfiguration(
            storeName,
            schema: schema,
            url: url ?? defaultStoreURL(),
            cloudKitDatabase: .none
        )
    }

    static func makeContainer(
        url: URL? = nil
    ) throws -> ModelContainer {
        let container = try ModelContainer(for: schema, configurations: configuration(url: url))
        HealthStoreBackupPolicy.refresh(container)
        return container
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    static func defaultStoreURL() -> URL {
        let fileManager = FileManager.default
        let applicationSupportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let directory = applicationSupportDirectory.appendingPathComponent("DUNE", isDirectory: true)
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return directory.appendingPathComponent(storeFilename, isDirectory: false)
    }
}
