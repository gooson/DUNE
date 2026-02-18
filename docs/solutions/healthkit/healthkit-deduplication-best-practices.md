---
tags: [healthkit, deduplication, source-filtering, async-await, swift]
date: 2026-02-18
category: solution
status: reviewed
---

# HealthKit Data Deduplication Best Practices

> Research on preventing double-counting when both Apple Watch and iPhone record the same type of data, source filtering, and linking local SwiftData records to HealthKit samples.

## Problem Statement

When users have both an iPhone and Apple Watch, HealthKit receives data from both devices for the same metrics (steps, active energy, workouts). Without proper deduplication, apps can display inflated values by counting the same activity twice.

## Core Concepts

### 1. How HKStatisticsQuery Handles Deduplication

#### Automatic Merge by HealthKit

`HKStatisticsQuery` and `HKStatisticsCollectionQuery` **automatically deduplicate data across sources** when configured correctly. This is the same merge algorithm that the native Health app uses.

**Key principle**: If you use `HKSampleQuery`, HealthKit returns ALL data from ALL sources (iPhone + Watch + third-party apps), and you'll receive duplicates. With statistics queries, HealthKit does the appropriate merging for you.

#### Merge Strategies via `HKStatisticsOptions`

The `options` parameter defines both the statistical calculation type AND the merge behavior:

| Option | Type | Use Case | Deduplication Behavior |
|--------|------|----------|------------------------|
| `.cumulativeSum` | Cumulative | Steps, distance, active energy | ✅ Deduplicates across sources |
| `.discreteAverage` | Discrete | Heart rate, body temperature | ✅ Averages across sources |
| `.discreteMin` | Discrete | Resting heart rate | ✅ Takes minimum across sources |
| `.discreteMax` | Discrete | Peak heart rate | ✅ Takes maximum across sources |
| `.discreteMostRecent` | Discrete | Body weight, body fat % | ✅ Takes most recent value |
| `.separateBySource` | Either | Debugging, source attribution | ⚠️ Per-source totals (NOT deduplicated) |

**Important**:
- Cumulative types (steps, calories) cannot use discrete options
- Discrete types (weight, heart rate) cannot use cumulative options
- `.separateBySource` gives you per-device totals but does NOT deduplicate overlapping data

#### Example: Proper Statistics Query

```swift
func fetchDailySteps(for date: Date) async throws -> Double? {
    let stepType = HKQuantityType(.stepCount)
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

    let predicate = HKQuery.predicateForSamples(
        withStart: startOfDay,
        end: endOfDay,
        options: .strictStartDate
    )

    return try await withCheckedThrowingContinuation { continuation in
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum  // ✅ Auto-deduplication
        ) { _, statistics, error in
            if let error = error {
                continuation.resume(throwing: error)
                return
            }

            let sum = statistics?.sumQuantity()?.doubleValue(for: .count())
            continuation.resume(returning: sum)
        }

        healthStore.execute(query)
    }
}
```

---

### 2. Source Identification with HKSource and HKSourceQuery

#### What is `HKSource`?

`HKSource` represents the app or device that created a HealthKit sample. Each source has:

- `name`: Human-readable name (e.g., "Apple Watch", "iPhone")
- `bundleIdentifier`: Unique app identifier (e.g., `com.apple.health`, `com.yourapp.fitness`)

#### Discovering Sources with `HKSourceQuery`

Use `HKSourceQuery` to find all apps/devices that have written a specific data type:

```swift
func fetchSources(for quantityType: HKQuantityType) async throws -> Set<HKSource> {
    return try await withCheckedThrowingContinuation { continuation in
        let query = HKSourceQuery(
            sampleType: quantityType,
            samplePredicate: nil
        ) { _, sources, error in
            if let error = error {
                continuation.resume(throwing: error)
                return
            }
            continuation.resume(returning: sources ?? [])
        }

        healthStore.execute(query)
    }
}

// Usage
let stepSources = try await fetchSources(for: HKQuantityType(.stepCount))
for source in stepSources {
    print("Source: \(source.name), Bundle: \(source.bundleIdentifier)")
}
```

#### Filter by Bundle Identifier

```swift
// Example: Get only sources from Apple apps
let appleSources = stepSources.filter {
    $0.bundleIdentifier.hasPrefix("com.apple")
}

// Example: Get only your app's source
let myAppSources = stepSources.filter {
    $0.bundleIdentifier == Bundle.main.bundleIdentifier
}
```

---

### 3. Filtering Samples by Source Using Predicates

#### Using `predicateForObjects(from:)`

To query samples from specific sources only:

```swift
func fetchSteps(from sources: Set<HKSource>, for date: Date) async throws -> [HKQuantitySample] {
    let stepType = HKQuantityType(.stepCount)
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

    // Combine date predicate + source predicate
    let datePredicate = HKQuery.predicateForSamples(
        withStart: startOfDay,
        end: endOfDay,
        options: .strictStartDate
    )
    let sourcePredicate = HKQuery.predicateForObjects(from: sources)
    let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [
        datePredicate,
        sourcePredicate
    ])

    return try await withCheckedThrowingContinuation { continuation in
        let query = HKSampleQuery(
            sampleType: stepType,
            predicate: compound,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, error in
            if let error = error {
                continuation.resume(throwing: error)
                return
            }
            continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
        }

        healthStore.execute(query)
    }
}
```

#### Filtering Your Own App's Data

```swift
// Get only workouts created by your app
let workoutTypePredicate = HKQuery.predicateForWorkouts(with: .other)
let sourcePredicate = HKQuery.predicateForObjects(from: HKSource.default())

let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [
    workoutTypePredicate,
    sourcePredicate
])

let query = HKSampleQuery(
    sampleType: .workoutType(),
    predicate: compound,
    limit: HKObjectQueryNoLimit,
    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
) { query, samples, error in
    // Only your app's workouts
}
```

#### Post-Query Filtering by Bundle Identifier

You can also filter after fetching:

```swift
// Filter sleep data to only Apple Health app
let sleepSamples = try await fetchSleepSamples(for: date)
let appleHealthOnly = sleepSamples.filter {
    $0.sourceRevision.source.bundleIdentifier == "com.apple.health"
}
```

---

### 4. Preventing Double-Counting: Apple Watch vs iPhone

#### Strategy 1: Use Statistics Query (Recommended)

**Best practice**: Always use `HKStatisticsQuery` with `.cumulativeSum` or appropriate discrete option. HealthKit's merge algorithm is superior to any manual deduplication.

```swift
// ✅ GOOD: Let HealthKit handle deduplication
func fetchDailyActiveEnergy(for date: Date) async throws -> Double? {
    let energyType = HKQuantityType(.activeEnergyBurned)
    let predicate = HKQuery.predicateForSamples(
        withStart: date.startOfDay,
        end: date.endOfDay,
        options: .strictStartDate
    )

    return try await withCheckedThrowingContinuation { continuation in
        let query = HKStatisticsQuery(
            quantityType: energyType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum  // Auto-deduplicated
        ) { _, stats, error in
            if let error {
                continuation.resume(throwing: error)
                return
            }
            let sum = stats?.sumQuantity()?.doubleValue(for: .kilocalorie())
            continuation.resume(returning: sum)
        }
        healthStore.execute(query)
    }
}
```

```swift
// ❌ BAD: Manual summation of samples (will double-count)
let samples = try await fetchEnergySamples(for: date)
let total = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .kilocalorie()) }
```

#### Strategy 2: Prioritize Apple Watch Sources

If you MUST use `HKSampleQuery` for some reason (e.g., need detailed sample-level data), prioritize Watch over iPhone:

```swift
func fetchStepsWithSourcePriority(for date: Date) async throws -> Double {
    let samples = try await fetchStepSamples(for: date)

    // Group by time interval and prioritize Watch
    var consolidatedSteps: [Date: Double] = [:]

    for sample in samples.sorted(by: { $0.startDate < $1.startDate }) {
        let interval = sample.startDate.roundedToMinute()
        let isWatch = sample.sourceRevision.source.name.contains("Watch")

        if let existing = consolidatedSteps[interval] {
            // Only override if this is Watch data
            if isWatch {
                consolidatedSteps[interval] = sample.quantity.doubleValue(for: .count())
            }
        } else {
            consolidatedSteps[interval] = sample.quantity.doubleValue(for: .count())
        }
    }

    return consolidatedSteps.values.reduce(0, +)
}
```

**Warning**: This manual approach is complex and unlikely to match HealthKit's internal algorithm. Use statistics queries whenever possible.

#### Strategy 3: Use `.separateBySource` for Debugging

```swift
func fetchStepsPerSource(for date: Date) async throws -> [String: Double] {
    let stepType = HKQuantityType(.stepCount)
    let predicate = HKQuery.predicateForSamples(
        withStart: date.startOfDay,
        end: date.endOfDay,
        options: .strictStartDate
    )

    return try await withCheckedThrowingContinuation { continuation in
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: [.cumulativeSum, .separateBySource]  // Per-source totals
        ) { _, stats, error in
            if let error {
                continuation.resume(throwing: error)
                return
            }

            var result: [String: Double] = [:]
            if let sources = stats?.sources {
                for source in sources {
                    let sum = stats?.sumQuantity(for: source)?.doubleValue(for: .count()) ?? 0
                    result[source.name] = sum
                }
            }
            continuation.resume(returning: result)
        }
        healthStore.execute(query)
    }
}

// Usage
let stepsPerSource = try await fetchStepsPerSource(for: Date())
// Example result: ["Apple Watch": 8432, "iPhone": 3210]
```

**Note**: These per-source totals are NOT deduplicated. Use this only for debugging or source attribution UI.

---

### 5. Linking Local SwiftData Records to HealthKit Samples

#### The UUID Matching Pattern

Every `HKObject` (including `HKSample`, `HKWorkout`, etc.) has a unique `uuid` property. This is the canonical way to link local records to HealthKit data.

#### SwiftData Model with HealthKit UUID

```swift
import SwiftData
import HealthKit

@Model
class WorkoutRecord {
    var hkUUID: UUID        // Matches HKWorkout.uuid
    var startDate: Date
    var endDate: Date
    var activityType: String
    var calories: Double
    var duration: TimeInterval

    // Optional: Store bundle identifier to filter by source later
    var sourceBundleIdentifier: String?

    init(from workout: HKWorkout) {
        self.hkUUID = workout.uuid
        self.startDate = workout.startDate
        self.endDate = workout.endDate
        self.activityType = workout.workoutActivityType.name
        self.calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
        self.duration = workout.duration
        self.sourceBundleIdentifier = workout.sourceRevision.source.bundleIdentifier
    }
}
```

#### Sync Pattern: Fetch → Deduplicate → Insert

```swift
@MainActor
func syncWorkoutsFromHealthKit(context: ModelContext) async throws {
    // 1. Fetch workouts from HealthKit
    let hkWorkouts = try await fetchRecentWorkouts()

    // 2. Fetch existing local UUIDs
    let descriptor = FetchDescriptor<WorkoutRecord>()
    let existingRecords = try context.fetch(descriptor)
    let existingUUIDs = Set(existingRecords.map(\.hkUUID))

    // 3. Filter to only new workouts
    let newWorkouts = hkWorkouts.filter { !existingUUIDs.contains($0.uuid) }

    // 4. Insert new records
    for workout in newWorkouts {
        let record = WorkoutRecord(from: workout)
        context.insert(record)
    }

    try context.save()
}

private func fetchRecentWorkouts() async throws -> [HKWorkout] {
    let predicate = HKQuery.predicateForSamples(
        withStart: Date().addingTimeInterval(-30 * 86400),  // Last 30 days
        end: Date(),
        options: .strictStartDate
    )

    return try await withCheckedThrowingContinuation { continuation in
        let query = HKSampleQuery(
            sampleType: .workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            if let error {
                continuation.resume(throwing: error)
                return
            }
            continuation.resume(returning: samples as? [HKWorkout] ?? [])
        }
        healthStore.execute(query)
    }
}
```

#### Alternative: Using `HKAnchoredObjectQuery` for Incremental Sync

For more efficient syncing, use anchored queries to fetch only changes since the last sync:

```swift
@Model
class SyncAnchor {
    var queryType: String  // e.g., "workout", "stepCount"
    var anchorData: Data?  // Encoded HKQueryAnchor
    var lastSyncDate: Date

    init(queryType: String) {
        self.queryType = queryType
        self.anchorData = nil
        self.lastSyncDate = Date()
    }
}

func syncWithAnchor(context: ModelContext) async throws {
    // 1. Fetch stored anchor
    let descriptor = FetchDescriptor<SyncAnchor>(
        predicate: #Predicate { $0.queryType == "workout" }
    )
    let anchors = try context.fetch(descriptor)
    let storedAnchor = anchors.first

    let anchor: HKQueryAnchor? = if let data = storedAnchor?.anchorData {
        try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    } else {
        nil
    }

    // 2. Fetch changes since anchor
    let (newSamples, deletedSamples, newAnchor) = try await fetchChanges(since: anchor)

    // 3. Process new samples
    for sample in newSamples {
        guard let workout = sample as? HKWorkout else { continue }
        let record = WorkoutRecord(from: workout)
        context.insert(record)
    }

    // 4. Process deletions
    for sample in deletedSamples {
        let descriptor = FetchDescriptor<WorkoutRecord>(
            predicate: #Predicate { $0.hkUUID == sample.uuid }
        )
        if let recordToDelete = try context.fetch(descriptor).first {
            context.delete(recordToDelete)
        }
    }

    // 5. Update anchor
    let newAnchorData = try NSKeyedArchiver.archivedData(
        withRootObject: newAnchor,
        requiringSecureCoding: true
    )
    if let storedAnchor {
        storedAnchor.anchorData = newAnchorData
        storedAnchor.lastSyncDate = Date()
    } else {
        let newRecord = SyncAnchor(queryType: "workout")
        newRecord.anchorData = newAnchorData
        context.insert(newRecord)
    }

    try context.save()
}

private func fetchChanges(since anchor: HKQueryAnchor?) async throws
    -> (added: [HKSample], deleted: [HKDeletedObject], newAnchor: HKQueryAnchor)
{
    return try await withCheckedThrowingContinuation { continuation in
        let query = HKAnchoredObjectQuery(
            type: .workoutType(),
            predicate: nil,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { _, added, deleted, newAnchor, error in
            if let error {
                continuation.resume(throwing: error)
                return
            }
            continuation.resume(returning: (
                added: added ?? [],
                deleted: deleted ?? [],
                newAnchor: newAnchor ?? HKQueryAnchor(fromValue: 0)
            ))
        }
        healthStore.execute(query)
    }
}
```

**Important**: `HKQueryAnchor` is type-specific. You cannot reuse an anchor from `.stepCount` for `.workoutType()`. Store separate anchors per data type.

---

## Summary Table

| Scenario | Recommended Approach | Why |
|----------|---------------------|-----|
| Get daily step total | `HKStatisticsQuery` with `.cumulativeSum` | Auto-deduplication across Watch + iPhone |
| Get average heart rate | `HKStatisticsQuery` with `.discreteAverage` | Proper averaging across sources |
| Need sample-level detail | `HKSampleQuery` + filter by source | Manual control, but beware double-counting |
| Filter to your app only | `predicateForObjects(from: HKSource.default())` | Excludes third-party apps |
| Filter to specific app | Post-filter by `bundleIdentifier` | Full control over source selection |
| Sync to SwiftData | UUID matching + `HKAnchoredObjectQuery` | Efficient incremental sync |
| Debug source attribution | `.separateBySource` option | See per-device totals (not deduplicated) |

---

## Key Pitfalls to Avoid

1. **Don't manually sum `HKSample` quantities for cumulative types** — Use `HKStatisticsQuery` instead
2. **Don't assume `.separateBySource` deduplicates** — It gives per-source totals WITH overlap
3. **Don't reuse `HKQueryAnchor` across different sample types** — Each type needs its own anchor
4. **Don't forget to handle deletions** — HealthKit can delete samples; use anchored queries to detect this
5. **Don't filter multiple data types in one query** — If any permission is denied, the entire result is empty

---

## Prevention Checklist

When implementing HealthKit queries in this project:

- [ ] Use `HKStatisticsQuery` for aggregated metrics (steps, calories, distance)
- [ ] Use `.cumulativeSum` for cumulative types, discrete options for discrete types
- [ ] Store `HKSample.uuid` in local SwiftData models for correlation
- [ ] Use `HKAnchoredObjectQuery` for efficient incremental syncing
- [ ] Filter by source only when you need attribution or debugging
- [ ] Wrap all HealthKit callbacks in `async/await` using `CheckedContinuation`
- [ ] Test with both iPhone-only and Watch+iPhone scenarios
- [ ] Handle permission denials gracefully per data type

---

## References

- [HKStatisticsQuery | Apple Developer Documentation](https://developer.apple.com/documentation/healthkit/hkstatisticsquery)
- [HKStatisticsOptions | Apple Developer Documentation](https://developer.apple.com/documentation/healthkit/hkstatisticsoptions)
- [The HealthKit HKStatisticsQuery - DevFright](https://www.devfright.com/the-healthkit-hkstatisticsquery/)
- [HKSourceQuery | Apple Developer Documentation](https://developer.apple.com/documentation/healthkit/hksourcequery)
- [How to use the HKSourceQuery - DevFright](https://www.devfright.com/how-to-use-the-hksourcequery/)
- [predicateForObjects(from:) | Apple Developer Documentation](https://developer.apple.com/documentation/healthkit/hkquery/predicateforobjects(from:)-7j3p2)
- [Running Queries with Swift Concurrency | Apple Developer Documentation](https://developer.apple.com/documentation/healthkit/queries/running_queries_with_swift_concurrency)
- [Reading data from HealthKit in a SwiftUI app](https://www.createwithswift.com/reading-data-from-healthkit-in-a-swiftui-app/)
- [Accessing Workouts with HealthKit and Swift - Bruno Scheufler](https://brunoscheufler.com/blog/2021-11-07-accessing-workouts-with-healthkit-and-swift)
- [Mastering HealthKit: Common Pitfalls and Solutions | Medium](https://medium.com/mobilepeople/mastering-healthkit-common-pitfalls-and-solutions-b4f46729f28e)
