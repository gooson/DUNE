import CryptoKit
import Foundation
import SwiftData

protocol RoutinePlanCloudStore {
    var dictionaryRepresentation: [String: Any] { get }
    func set(_ object: Any?, forKey key: String)
    func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: RoutinePlanCloudStore {}

/// The complete iCloud payload for a routine. Entry IDs identify plan rows, not workouts.
struct RoutinePlanProjection: Codable, Equatable {
    struct Entry: Codable, Equatable {
        let id: UUID
        let catalogID: String
        let plannedSets: Int
        let plannedReps: Int
    }
    let id: UUID
    let entries: [Entry]

    init?(_ template: WorkoutTemplate) {
        id = template.id
        entries = template.exerciseEntries.map { Entry(id: $0.id, catalogID: $0.exerciseDefinitionID,
                                                       plannedSets: $0.defaultSets, plannedReps: $0.defaultReps) }
        guard isValid else { return nil }
    }

    /// Check the actual bundled catalog, rather than trusting arbitrary strings shaped like IDs.
    var isValid: Bool {
        !entries.isEmpty && entries.count <= 100 && Set(entries.map(\.id)).count == entries.count
            && entries.allSatisfy {
                ExerciseLibraryService.shared.exercise(byID: $0.catalogID)?.id == $0.catalogID
                    && (1...20).contains($0.plannedSets) && (1...100).contains($0.plannedReps)
            }
    }

    var catalogTitle: String {
        String(entries.compactMap { ExerciseLibraryService.shared.exercise(byID: $0.catalogID)?.localizedName }
            .joined(separator: " · ").prefix(100))
    }

    @MainActor
    func restore(existing: WorkoutTemplate?, in context: ModelContext) {
        let row = existing ?? WorkoutTemplate(name: catalogTitle)
        let byID = Dictionary(grouping: row.exerciseEntries, by: \.id)
        row.id = id
        row.exerciseEntries = entries.map { entry in
            if var local = byID[entry.id]?.first, local.exerciseDefinitionID == entry.catalogID {
                local.defaultSets = entry.plannedSets
                local.defaultReps = entry.plannedReps
                return local
            }
            let catalog = ExerciseLibraryService.shared.exercise(byID: entry.catalogID)
            var new = TemplateEntry(exerciseDefinitionID: entry.catalogID, exerciseName: catalog?.localizedName ?? entry.catalogID,
                                    defaultSets: entry.plannedSets, defaultReps: entry.plannedReps,
                                    equipment: catalog?.equipment.rawValue, inputTypeRaw: catalog?.inputType.rawValue,
                                    cardioSecondaryUnitRaw: catalog?.cardioSecondaryUnit?.rawValue)
            new.id = entry.id
            return new
        }
        if existing == nil { context.insert(row) }
    }

    /// A remote deletion or replacement must not discard unsynced local contents.
    static func canApply(_ incoming: Self?, over local: WorkoutTemplate) -> Bool {
        guard let projection = Self(local) else { return false }
        if incoming == nil && local.name != projection.catalogTitle { return false }
        return local.exerciseEntries.allSatisfy { old in
            if incoming?.entries.contains(where: { $0.id == old.id && $0.catalogID == old.exerciseDefinitionID }) == true {
                return true
            }
            let catalog = ExerciseLibraryService.shared.exercise(byID: old.exerciseDefinitionID)
            return old.defaultWeightKg == nil && old.restDuration == nil
                && [catalog?.name, catalog?.localizedName].contains(old.exerciseName)
                && (old.equipment == nil || old.equipment == catalog?.equipment.rawValue)
                && (old.inputTypeRaw == nil || old.inputTypeRaw == catalog?.inputType.rawValue)
                && (old.cardioSecondaryUnitRaw == nil || old.cardioSecondaryUnitRaw == catalog?.cardioSecondaryUnit?.rawValue)
        }
    }
}

/// Independent per-device slots prevent simultaneous offline edits from overwriting each other.
struct RoutinePlanRevision: Codable, Equatable {
    let version: Int
    let clock: [String: Int]
    let plan: RoutinePlanProjection?

    func dominates(_ other: Self) -> Bool {
        clock != other.clock && other.clock.allSatisfy { clock[$0.key, default: 0] >= $0.value }
    }

    static func heads(_ revisions: [Self]) -> [Self] {
        revisions.filter { candidate in !revisions.contains { $0.dominates(candidate) } }
    }
}

@MainActor
enum ExerciseLibraryBackup {
    private static let prefix = "dune.routinePlan.v1."
    private static let baselineKey = "dune.routinePlan.lastSynced.v1"
    private static let deletionsKey = "dune.routinePlan.deleted.v1"
    enum Action { case unchanged, upload, restore, conflict, wait }

    static func action(local: String?, baseline: String?, remote: String?, deleted: Bool) -> Action {
        guard let remote else {
            if baseline != nil { return .wait }
            return local != nil && !deleted ? .upload : .unchanged
        }
        let desired = deleted ? "deleted" : local
        guard let desired else { return remote == "deleted" ? .unchanged : .restore }
        if desired == remote { return .unchanged }
        if baseline == remote { return .upload }
        if baseline == desired && !deleted { return .restore }
        return .conflict
    }

    static func isLibraryKey(_ key: String) -> Bool { key.hasPrefix(prefix) }

    /// Restoring an old device backup must not restore its iCloud writer identity.
    private static func writerID() throws -> String {
        let root = URL.applicationSupportDirectory.appending(path: "RoutinePlanWriter", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var directory = root
        var attributes = URLResourceValues()
        attributes.isExcludedFromBackup = true
        try directory.setResourceValues(attributes)
        let url = root.appending(path: "writer")
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            guard let id = UUID(uuidString: text) else { throw CocoaError(.fileReadCorruptFile) }
            return id.uuidString
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            let id = UUID().uuidString
            try Data(id.utf8).write(to: url, options: [.withoutOverwriting, .completeFileProtection])
            return id
        }
    }

    private static func fingerprint(_ plan: RoutinePlanProjection?) throws -> String {
        guard let plan else { return "deleted" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try SHA256.hash(data: encoder.encode(plan)).map { String(format: "%02x", $0) }.joined()
    }

    static func didSaveRoutine(in context: ModelContext) {
        do {
            try context.save()
            synchronize(in: context)
        } catch {
            AppLogger.data.error("Could not save routine plan: \(error, privacy: .private)")
        }
    }

    static func didDelete(templateID: UUID, in context: ModelContext) {
        do {
            try context.save()
            let defaults = UserDefaults.standard
            var deleted = Set(defaults.stringArray(forKey: deletionsKey) ?? [])
            deleted.insert(templateID.uuidString)
            defaults.set(Array(deleted), forKey: deletionsKey)
            synchronize(in: context)
        } catch {
            AppLogger.data.error("Could not save routine deletion: \(error, privacy: .private)")
        }
    }

    @discardableResult
    static func synchronize(in context: ModelContext) -> Bool {
        guard UserDefaults.standard.bool(forKey: CloudSyncPreferenceStore.storageKey) else { return false }
        let cloud = NSUbiquitousKeyValueStore.default
        guard cloud.synchronize() else { return false }
        do {
            // A backup callback must not commit unrelated pending edits on a UI context.
            let backupContext = ModelContext(context.container)
            backupContext.autosaveEnabled = false
            return try reconcile(in: backupContext, cloud: cloud, writer: writerID(), defaults: .standard)
        } catch {
            AppLogger.data.error("Routine plan backup unavailable: \(error, privacy: .private)")
            return false
        }
    }

    static func reconcile(in context: ModelContext, cloud: any RoutinePlanCloudStore, writer: String, defaults: UserDefaults) throws -> Bool {
        let routines = Dictionary(grouping: try context.fetch(FetchDescriptor<WorkoutTemplate>()), by: { $0.id.uuidString })
        var baseline = defaults.dictionary(forKey: baselineKey) as? [String: String] ?? [:]
        var deletions = Set(defaults.stringArray(forKey: deletionsKey) ?? [])
        var revisions: [String: [RoutinePlanRevision]] = [:]
        var blocked = Set<String>()
        let contents = cloud.dictionaryRepresentation
        for (key, value) in contents where isLibraryKey(key) {
            let parts = key.dropFirst(prefix.count).split(separator: ".")
            guard parts.count == 2, let uuid = UUID(uuidString: String(parts[0])) else { continue }
            let id = uuid.uuidString
            guard UUID(uuidString: String(parts[1])) != nil, let data = value as? Data, data.count <= 32_768,
                  let rev = try? JSONDecoder().decode(RoutinePlanRevision.self, from: data), rev.version == 1,
                  rev.clock[String(parts[1])] != nil, rev.clock.count <= 64,
                  rev.clock.allSatisfy({ UUID(uuidString: $0.key) != nil && (1...Int.max / 2).contains($0.value) }),
                  rev.plan == nil || (rev.plan?.isValid == true && rev.plan?.id == uuid) else {
                blocked.insert(id)
                continue
            }
            revisions[id, default: []].append(rev)
        }

        var uploads: [String: Data] = [:]
        let ids = Set(routines.keys).union(revisions.keys).union(deletions)
        for id in ids.sorted() where !blocked.contains(id) {
            guard (routines[id]?.count ?? 0) <= 1 else { blocked.insert(id); continue }
            let row = routines[id]?.first
            let local = row.flatMap(RoutinePlanProjection.init)
            // Unknown/custom catalog IDs and malformed existing routines stay untouched.
            if row != nil && local == nil { continue }
            let heads = RoutinePlanRevision.heads(revisions[id] ?? [])
            guard Set(try heads.map { try fingerprint($0.plan) }).count <= 1 else { blocked.insert(id); continue }
            let remote = heads.first
            let remoteDigest = try remote.map { try fingerprint($0.plan) }
            let localDigest = try local.map { try fingerprint($0) }
            switch action(local: localDigest, baseline: baseline[id], remote: remoteDigest, deleted: deletions.contains(id)) {
            case .wait: continue
            case .conflict: blocked.insert(id)
            case .unchanged:
                baseline[id] = remoteDigest
                if remoteDigest == "deleted" { deletions.remove(id) }
            case .restore:
                if let row, !RoutinePlanProjection.canApply(remote?.plan, over: row) { blocked.insert(id); continue }
                if let plan = remote?.plan { plan.restore(existing: row, in: context) }
                else if let row { context.delete(row) }
                baseline[id] = remoteDigest
            case .upload:
                var clock = heads.reduce(into: [String: Int]()) { $0.merge($1.clock, uniquingKeysWith: max) }
                guard clock.count < 64 || clock[writer] != nil else { blocked.insert(id); continue }
                clock[writer, default: 0] += 1
                let payload = deletions.contains(id) ? nil : local
                let rev = RoutinePlanRevision(version: 1, clock: clock, plan: payload)
                let data = try JSONEncoder().encode(rev)
                guard data.count <= 32_768 else { blocked.insert(id); continue }
                uploads[prefix + id + "." + writer] = data
                baseline[id] = try fingerprint(payload)
                deletions.remove(id)
            }
        }
        try context.save()
        let projected = contents.merging(uploads.mapValues { $0 as Any }, uniquingKeysWith: { _, new in new })
        guard projected.count <= 1_000,
              try PropertyListSerialization.data(fromPropertyList: projected, format: .binary, options: 0).count <= 950_000 else {
            AppLogger.data.error("Routine plan backup exceeds available iCloud preference space")
            return false
        }
        for (key, data) in uploads { cloud.set(data, forKey: key) }
        guard cloud.synchronize() else { return false }
        defaults.set(baseline, forKey: baselineKey)
        defaults.set(Array(deletions), forKey: deletionsKey)
        if !blocked.isEmpty { AppLogger.data.error("Routine plan backup preserved conflicting or unsupported entries") }
        return blocked.isEmpty
    }
}
