#if os(iOS)
import Foundation
import CryptoKit
import HealthKit
import SQLite3

struct NearbyWorkoutPlaceCursor: Codable, Sendable, Equatable, Comparable {
    let date: Date
    let id: UUID
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.date == rhs.date ? lhs.id.uuidString < rhs.id.uuidString : lhs.date < rhs.date
    }
}

struct NearbyWorkoutPageRequest: Codable, Sendable, Equatable {
    enum Kind: String, Codable { case recent, changes, idle }
    let sourceID: UUID
    let kind: Kind
    var anchor: Data?
    var placeCursor: NearbyWorkoutPlaceCursor?
    var includesHealthSnapshot: Bool { kind == .recent }
}


/// A read-only copy for Macs without a HealthKit store. Never use this as a HealthKit write input.
struct NearbyWorkoutHistory: Codable, Sendable {
    struct Entry: Codable, Sendable {
        let workout: WorkoutSummary
        let location: WorkoutLocationPayload?
        // A saved place, including an explicit removal, wins over HealthKit's original place.
        var placeEditedAt: Date?
    }

    let version: Int
    let fetchedAt: Date
    let entries: [Entry]
    var deletedIDs: Set<UUID> = []
    var sourceID: UUID?
    var request: NearbyWorkoutPageRequest?
    var nextAnchor: Data?
    var hasMore: Bool?
    var healthSnapshot: HealthSnapshotMirrorMapper.Payload?
    struct PlaceEdit: Codable, Sendable {
        let cursor: NearbyWorkoutPlaceCursor
        let location: WorkoutLocationPayload
    }
    var placeEdits: [PlaceEdit]?


    static let maxEntries = 2_000
    static let maxBytes = 16 * 1_024 * 1_024
    static func capture(
        request: NearbyWorkoutPageRequest,
        savedLocations: [String: WorkoutLocationPayload] = [:],
        locationEditDates: [String: Date] = [:],
        healthSnapshot: HealthSnapshotMirrorMapper.Payload? = nil
    ) async throws -> Data {
        let sourceID = try await installationID()
        guard request.sourceID == sourceID, request.kind != .idle,
              (request.anchor?.count ?? 0) <= 8_192 else { throw CocoaError(.fileReadCorruptFile) }
        let end = Date()
        let service = WorkoutQueryService(manager: .shared)
        let pageSize = 8 // Even dense normalized routes fit in the bounded transport frame.
        let workouts: [WorkoutSummary]
        var deletedIDs = Set<UUID>()
        var nextAnchor: Data?
        var hasMore: Bool?
        switch request.kind {
        case .recent:
            workouts = try await service.fetchWorkouts(start: .distantPast, end: end, limit: pageSize)
        case .changes:
            let anchor = try request.anchor.map { bytes in
                guard let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: bytes)
                else { throw CocoaError(.fileReadCorruptFile) }
                return anchor
            }
            try await HealthKitManager.shared.ensureNotDenied(for: HKObjectType.workoutType())
            let descriptor = HKAnchoredObjectQueryDescriptor(predicates: [.workout()], anchor: anchor, limit: pageSize)
            let result = try await descriptor.result(for: HealthKitManager.shared.healthStore)
            workouts = result.addedSamples.map(service.toSummary)
            deletedIDs = Set(result.deletedObjects.map(\.uuid))
            nextAnchor = try NSKeyedArchiver.archivedData(withRootObject: result.newAnchor, requiringSecureCoding: true)
            hasMore = workouts.count + deletedIDs.count >= pageSize
        case .idle:
            throw CocoaError(.fileReadCorruptFile)
        }
        let overrides = savedLocations.reduce(into: [UUID: WorkoutLocationPayload]()) { result, pair in
            if let id = UUID(uuidString: pair.key) { result[id] = pair.value }
        }
        let edits = locationEditDates.reduce(into: [UUID: Date]()) { result, pair in
            if let id = UUID(uuidString: pair.key) { result[id] = pair.value }
        }
        let routes = WorkoutRouteQueryService()
        var entries: [Entry] = []
        for var workout in workouts {
            try Task.checkCancellation()
            guard let id = UUID(uuidString: workout.id) else { throw CocoaError(.fileReadCorruptFile) }
            workout.peerDisplayTitle = WorkoutTypeCorrectionStore.shared.correctedTitle(for: workout.id)
            let saved = overrides[id]
            let healthLocation = saved?.route.isEmpty == false
                ? nil : try await routes.fetchLocation(workoutID: workout.id, forArchive: true)
            try Task.checkCancellation()
            let location = Self.displayLocation(saved: saved, health: healthLocation, indoor: workout.isIndoor)
            entries.append(Entry(workout: workout, location: location,
                                 placeEditedAt: saved == nil ? nil : min(edits[id] ?? end, end)))
        }
        if request.kind == .recent {
            let local = await DeletedWorkoutTombstoneStore.shared.tombstonedIDs
            deletedIDs.formUnion(local.compactMap(UUID.init(uuidString:)))
        }
        var placeEdits = [PlaceEdit]()
        if request.kind == .changes {
            let changed = edits.compactMap { id, date -> NearbyWorkoutPlaceCursor? in
                guard overrides[id] != nil, date <= end else { return nil }
                let cursor = NearbyWorkoutPlaceCursor(date: date, id: id)
                return request.placeCursor.map { $0 < cursor } ?? true ? cursor : nil
            }.sorted()
            placeEdits = changed.prefix(4).compactMap { cursor in
                overrides[cursor.id].map { PlaceEdit(cursor: cursor, location: $0) }
            }
            if changed.count > placeEdits.count { hasMore = true }
        }
        let history = Self(version: 3, fetchedAt: end, entries: entries, deletedIDs: deletedIDs,
                           sourceID: sourceID, request: request, nextAnchor: nextAnchor, hasMore: hasMore,
                           healthSnapshot: request.includesHealthSnapshot ? healthSnapshot : nil, placeEdits: placeEdits)
        let data = try JSONEncoder().encode(history)
        guard data.count <= maxBytes else { throw CocoaError(.fileWriteOutOfSpace) }
        return data
    }

    static func displayLocation(saved: WorkoutLocationPayload?, health: WorkoutLocationPayload?, indoor: Bool?) -> WorkoutLocationPayload? {
        guard let saved else { return health }
        return WorkoutLocationPayload(isIndoor: saved.isIndoor ?? health?.isIndoor ?? indoor,
                                      route: saved.route.isEmpty ? health?.route ?? [] : saved.route,
                                      place: saved.place)
    }

    @MainActor static func installationID() throws -> UUID {
        var directory = URL.applicationSupportDirectory.appending(path: "NearbyWorkoutPublisher")
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        let url = directory.appending(path: "source-id")
        do {
            let raw = try String(contentsOf: url, encoding: .utf8)
            guard let id = UUID(uuidString: raw) else { throw CocoaError(.fileReadCorruptFile) }
            return id
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            let id = UUID()
            try Data(id.uuidString.utf8).write(to: url, options: [.atomic, .completeFileProtection])
            return id
        }
    }

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= maxBytes else { throw CocoaError(.fileReadTooLarge) }
        let history = try JSONDecoder().decode(Self.self, from: data)
        var seen: Set<UUID> = []
        guard (history.version == 1 && history.sourceID == nil) || (history.version == 2 && history.sourceID != nil) ||
                (history.version == 3 && history.request?.sourceID == history.sourceID && history.sourceID != nil &&
                 history.request?.kind != .idle && (history.request?.kind != .changes || history.nextAnchor != nil)),
              (history.placeEdits?.count ?? 0) <= 4,
              history.placeEdits?.allSatisfy({ edit in
                  edit.cursor.date <= history.fetchedAt && edit.location.route.count <= WorkoutLocationPayload.maxRoutePoints
              }) ?? true,
              (history.nextAnchor?.count ?? 0) <= 8_192, (history.request?.anchor?.count ?? 0) <= 8_192,
              history.entries.count <= maxEntries, history.deletedIDs.count <= 10_000,
              history.version < 3 || history.entries.count <= 8,
              history.hasMore != true || history.nextAnchor != history.request?.anchor || !(history.placeEdits ?? []).isEmpty,
              history.fetchedAt <= Date.now.addingTimeInterval(300),
              history.entries.allSatisfy({ entry in
                  let w = entry.workout
                  guard let id = UUID(uuidString: w.id), seen.insert(id).inserted,
                        w.duration.isFinite, w.duration >= 0, w.date <= history.fetchedAt,
                        (entry.location?.route.count ?? 0) <= WorkoutLocationPayload.maxRoutePoints,
                        entry.placeEditedAt.map({ $0 <= history.fetchedAt && entry.location != nil }) ?? true
                  else { return false }
                  return true
              }) else { throw CocoaError(.fileReadCorruptFile) }
        return history
    }
}

/// Local-only SQLite index. An acknowledged page commits its rows, deletions and source-specific
/// HealthKit anchor in a single transaction. The number of pages is independent of the frame size.
actor NearbyWorkoutCache {
    static let shared = NearbyWorkoutCache()
    static let didChange = Notification.Name("DUNENearbyWorkoutCacheDidChange")
    private let root: URL
    private var openStore: (scope: String, db: Store)?

    init(root: URL = URL.applicationSupportDirectory.appending(path: "NearbyWorkoutHistory")) {
        self.root = root
    }

    private enum Field { case text(String), blob(Data), number(Double), null }
    private final class Store {
        let handle: OpaquePointer
        init(url: URL) throws {
            var db: OpaquePointer?
            let result = sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
            guard result == SQLITE_OK, let db else {
                if let db { sqlite3_close(db) }
                throw CocoaError(.fileReadUnknown)
            }
            handle = db
            try query("PRAGMA synchronous = FULL")
            try query("CREATE TABLE IF NOT EXISTS sources (source TEXT PRIMARY KEY, fetched REAL NOT NULL, recent REAL NOT NULL, anchor BLOB, polled REAL NOT NULL, pending INTEGER NOT NULL)")
            try query("CREATE TABLE IF NOT EXISTS records (source TEXT NOT NULL, id TEXT NOT NULL, date REAL NOT NULL, seen REAL NOT NULL, entry BLOB NOT NULL, PRIMARY KEY(source,id))")
            try query("CREATE INDEX IF NOT EXISTS by_date ON records(date)")
            try query("CREATE INDEX IF NOT EXISTS by_id ON records(id)")
            try query("CREATE TABLE IF NOT EXISTS edits (source TEXT NOT NULL,id TEXT NOT NULL,date REAL NOT NULL,location BLOB NOT NULL,PRIMARY KEY(source,id))")
            try query("CREATE INDEX IF NOT EXISTS edit_by_id ON edits(id,date)")
            try query("CREATE TABLE IF NOT EXISTS edit_cursor (source TEXT PRIMARY KEY,cursor BLOB NOT NULL)")
            try query("CREATE TABLE IF NOT EXISTS deleted (id TEXT PRIMARY KEY)")
            try query("CREATE TABLE IF NOT EXISTS health (slot INTEGER PRIMARY KEY CHECK(slot=1), fetched REAL NOT NULL, payload BLOB NOT NULL)")
        }

        deinit { sqlite3_close(handle) }

        func query(_ sql: String, _ values: [Field] = [], visit: (OpaquePointer) throws -> Void = { _ in }) throws {
            var prepared: OpaquePointer?
            guard sqlite3_prepare_v2(handle, sql, -1, &prepared, nil) == SQLITE_OK, let statement = prepared
            else { throw CocoaError(.fileReadCorruptFile) }
            defer { sqlite3_finalize(statement) }
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            for (index, value) in values.enumerated() {
                let position = Int32(index + 1)
                let result: Int32
                switch value {
                case .text(let text): result = sqlite3_bind_text(statement, position, text, -1, transient)
                case .number(let number): result = sqlite3_bind_double(statement, position, number)
                case .blob(let bytes): result = bytes.withUnsafeBytes {
                    sqlite3_bind_blob(statement, position, $0.baseAddress, Int32($0.count), transient)
                }
                case .null: result = sqlite3_bind_null(statement, position)
                }
                guard result == SQLITE_OK else { throw CocoaError(.fileWriteUnknown) }
            }
            while true {
                switch sqlite3_step(statement) {
                case SQLITE_ROW: try visit(statement)
                case SQLITE_DONE: return
                default: throw CocoaError(.fileReadCorruptFile)
                }
            }
        }

        static func bytes(_ statement: OpaquePointer, _ index: Int32) -> Data? {
            guard let ptr = sqlite3_column_blob(statement, index) else { return nil }
            return Data(bytes: ptr, count: Int(sqlite3_column_bytes(statement, index)))
        }
    }

    private struct State {
        var fetched = -Double.greatestFiniteMagnitude
        var recent = -Double.greatestFiniteMagnitude
        var anchor: Data?
        var polled = -Double.greatestFiniteMagnitude
        var pending = true
        var placeCursor: NearbyWorkoutPlaceCursor?
    }

    private func store(scope: String, create: Bool) throws -> Store? {
        if let openStore, openStore.scope == scope { return openStore.db }
        let name = SHA256.hash(data: Data(scope.utf8)).map { String(format: "%02x", $0) }.joined()
        let path = root.appending(path: name + ".sqlite")
        let legacy = root.appending(path: name + ".json")
        let fm = FileManager.default
        let hasLegacy = fm.fileExists(atPath: legacy.path)
        guard create || hasLegacy || fm.fileExists(atPath: path.path) else { return nil }
        var directory = root
        try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        var attributes = URLResourceValues()
        attributes.isExcludedFromBackup = true
        try directory.setResourceValues(attributes)
        let db = try Store(url: path)
        if hasLegacy {
            guard (try legacy.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= NearbyWorkoutHistory.maxBytes
            else { throw CocoaError(.fileReadTooLarge) }
            let history = try NearbyWorkoutHistory.decode(Data(contentsOf: legacy))
            _ = try apply(history, to: db)
            try fm.removeItem(at: legacy)
        }
        openStore = (scope, db)
        return db
    }

    func request(source: UUID, scope: String) throws -> NearbyWorkoutPageRequest {
        let s = try store(scope: scope, create: false).map { try state(source.uuidString, in: $0) } ?? State()
        let now = Date.now.timeIntervalSinceReferenceDate
        if now - s.recent >= 300 { return .init(sourceID: source, kind: .recent) }
        if s.pending || now - s.polled >= 300 { return .init(sourceID: source, kind: .changes, anchor: s.anchor, placeCursor: s.placeCursor) }
        return .init(sourceID: source, kind: .idle)
    }

    private func state(_ source: String, in db: Store) throws -> State {
        var state = State()
        try db.query("SELECT fetched,recent,anchor,polled,pending FROM sources WHERE source=?", [.text(source)]) { row in
            state = State(fetched: sqlite3_column_double(row, 0), recent: sqlite3_column_double(row, 1),
                          anchor: Store.bytes(row, 2), polled: sqlite3_column_double(row, 3), pending: sqlite3_column_int(row, 4) != 0)
        }
        try db.query("SELECT cursor FROM edit_cursor WHERE source=?", [.text(source)]) { row in
            guard let data = Store.bytes(row, 0) else { throw CocoaError(.fileReadCorruptFile) }
            state.placeCursor = try JSONDecoder().decode(NearbyWorkoutPlaceCursor.self, from: data)
        }
        return state
    }

    func accept(_ data: Data, scope: String) throws {
        let history = try NearbyWorkoutHistory.decode(data)
        guard let db = try store(scope: scope, create: true) else { throw CocoaError(.fileWriteUnknown) }
        if try apply(history, to: db) { NotificationCenter.default.post(name: Self.didChange, object: nil) }
    }

    private func apply(_ history: NearbyWorkoutHistory, to db: Store) throws -> Bool {
        let source = history.sourceID?.uuidString ?? "legacy"
        let seen = history.fetchedAt.timeIntervalSinceReferenceDate
        let now = Date.now.timeIntervalSinceReferenceDate
        try db.query("BEGIN IMMEDIATE")
        do {
            var s = try state(source, in: db)
            if let request = history.request, request.kind == .changes {
                guard s.anchor == request.anchor, s.placeCursor == request.placeCursor else {
                    try db.query("ROLLBACK")
                    return false
                }
                s.anchor = history.nextAnchor
                s.pending = history.hasMore == true
                s.polled = now
            } else {
                guard s.fetched < seen else {
                    try db.query("ROLLBACK")
                    return false
                }
                s.recent = now
            }
            for id in history.deletedIDs {
                try db.query("INSERT OR IGNORE INTO deleted(id) VALUES(?)", [.text(id.uuidString)])
                try db.query("DELETE FROM records WHERE id=?", [.text(id.uuidString)])
                try db.query("DELETE FROM edits WHERE id=?", [.text(id.uuidString)])
            }
            let encoder = JSONEncoder()
            for entry in history.entries {
                guard let id = UUID(uuidString: entry.workout.id) else { throw CocoaError(.fileReadCorruptFile) }
                var old: NearbyWorkoutHistory.Entry?
                try db.query("SELECT entry FROM records WHERE source=? AND id=?", [.text(source), .text(id.uuidString)]) { row in
                    old = try Self.entry(row)
                }
                let merged = Self.overlay(entry, on: old)
                let bytes = try encoder.encode(merged)
                try db.query("""
                    INSERT OR REPLACE INTO records(source,id,date,seen,entry)
                    SELECT ?,?,?,?,? WHERE NOT EXISTS(SELECT 1 FROM deleted WHERE id=?)
                    """, [.text(source), .text(id.uuidString), .number(entry.workout.date.timeIntervalSinceReferenceDate),
                          .number(seen), .blob(bytes), .text(id.uuidString)])
            }
            for edit in history.placeEdits ?? [] {
                guard s.placeCursor.map({ $0 < edit.cursor }) ?? true else { throw CocoaError(.fileReadCorruptFile) }
                let id = edit.cursor.id.uuidString
                try db.query("""
                    INSERT OR REPLACE INTO edits(source,id,date,location)
                    SELECT ?,?,?,? WHERE NOT EXISTS(SELECT 1 FROM deleted WHERE id=?)
                    """, [.text(source), .text(id), .number(edit.cursor.date.timeIntervalSinceReferenceDate),
                          .blob(try encoder.encode(edit.location)), .text(id)])
                s.placeCursor = edit.cursor
            }
            if let cursor = s.placeCursor {
                try db.query("INSERT OR REPLACE INTO edit_cursor VALUES(?,?)", [.text(source), .blob(try encoder.encode(cursor))])
            }
            if let health = history.healthSnapshot {
                let bytes = try encoder.encode(health)
                let stamp = health.fetchedAt.timeIntervalSinceReferenceDate
                guard stamp <= now + 300 else { throw CocoaError(.fileReadCorruptFile) }
                try db.query("""
                    INSERT INTO health(slot,fetched,payload) VALUES(1,?,?)
                    ON CONFLICT(slot) DO UPDATE SET fetched=excluded.fetched,payload=excluded.payload
                    WHERE excluded.fetched > health.fetched
                    """, [.number(stamp), .blob(bytes)])
            }
            try db.query("INSERT OR REPLACE INTO sources(source,fetched,recent,anchor,polled,pending) VALUES(?,?,?,?,?,?)",
                         [.text(source), .number(max(seen, s.fetched)), .number(s.recent), s.anchor.map(Field.blob) ?? .null,
                          .number(s.polled), .number(s.pending ? 1 : 0)])
            try db.query("COMMIT")
        } catch {
            try? db.query("ROLLBACK")
            throw error
        }
        return true
    }

    private static func entry(_ row: OpaquePointer) throws -> NearbyWorkoutHistory.Entry {
        guard let bytes = Store.bytes(row, 0) else { throw CocoaError(.fileReadCorruptFile) }
        return try JSONDecoder().decode(NearbyWorkoutHistory.Entry.self, from: bytes)
    }

    private static func overlay(_ new: NearbyWorkoutHistory.Entry, on old: NearbyWorkoutHistory.Entry?) -> NearbyWorkoutHistory.Entry {
        guard let old else { return new }
        guard let location = new.location else {
            return .init(workout: new.workout, location: old.location, placeEditedAt: old.placeEditedAt)
        }
        let keepOldEdit = old.placeEditedAt.map { $0 > (new.placeEditedAt ?? .distantPast) } ?? false
        let place: WorkoutPlace?
        if keepOldEdit {
            place = old.location?.place
        } else if new.placeEditedAt != nil {
            place = location.place
        } else {
            place = location.place ?? old.location?.place
        }
        let combined = WorkoutLocationPayload(isIndoor: location.isIndoor ?? old.location?.isIndoor,
                                              route: location.route.isEmpty ? old.location?.route ?? [] : location.route,
                                              place: place)
        return .init(workout: new.workout, location: combined, placeEditedAt: keepOldEdit ? old.placeEditedAt : new.placeEditedAt)
    }

    func workouts(start: Date, end: Date, scope: String?) throws -> [WorkoutSummary] {
        guard let scope, start <= end, let db = try store(scope: scope, create: false) else { return [] }
        var entries = [String: WorkoutSummary]()
        try db.query("SELECT entry FROM records WHERE date BETWEEN ? AND ? ORDER BY seen,source",
                     [.number(start.timeIntervalSinceReferenceDate), .number(end.timeIntervalSinceReferenceDate)]) { row in
            let item = try Self.entry(row).workout
            entries[item.id.uppercased()] = item
        }
        return entries.values.sorted {
            if $0.date == $1.date { return $0.id < $1.id }
            return $0.date > $1.date
        }
    }

    func location(id: String, scope: String?) throws -> WorkoutLocationPayload? {
        guard let scope, let uuid = UUID(uuidString: id), let db = try store(scope: scope, create: false) else { return nil }
        var entry: NearbyWorkoutHistory.Entry?
        try db.query("SELECT entry FROM records WHERE id=? ORDER BY seen,source", [.text(uuid.uuidString)]) { row in
            entry = Self.overlay(try Self.entry(row), on: entry)
        }
        var saved: WorkoutLocationPayload?
        try db.query("SELECT location,date FROM edits WHERE id=? ORDER BY date DESC,source LIMIT 1",
                     [.text(uuid.uuidString)]) { row in
            let stamp = Date(timeIntervalSinceReferenceDate: sqlite3_column_double(row, 1))
            guard stamp >= (entry?.placeEditedAt ?? .distantPast), let data = Store.bytes(row, 0) else { return }
            saved = try JSONDecoder().decode(WorkoutLocationPayload.self, from: data)
        }
        return NearbyWorkoutHistory.displayLocation(saved: saved, health: entry?.location, indoor: entry?.workout.isIndoor)
    }

    func healthSnapshot(scope: String?) throws -> HealthSnapshotMirrorMapper.Payload? {
        guard let scope, let db = try store(scope: scope, create: false) else { return nil }
        var payload: HealthSnapshotMirrorMapper.Payload?
        try db.query("SELECT payload FROM health WHERE slot=1") { row in
            guard let data = Store.bytes(row, 0) else { throw CocoaError(.fileReadCorruptFile) }
            payload = try JSONDecoder().decode(HealthSnapshotMirrorMapper.Payload.self, from: data)
        }
        return payload
    }
}
#endif
