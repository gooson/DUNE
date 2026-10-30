# Siri health query architecture review

Reviewed `origin/main...a68e923f7ebd837c4ad068b4dd9a79d3a568a824` (changed Swift production code only). Read-only review; no build or test execution. The unit test run was already in progress with source frozen.

## Final delta review: `a68e923f..9ae252af61f76afc075c08fc1f995c7b82c4fea1`

The four original findings are resolved for this scope:

- **Record detail boundary (P2)**: `HealthQueryRecordDetailView` now receives `HealthQuerying` and checks the selected source ID through that service before and after raw record resolution; it also checks protected-data availability and clears rendered records on lock notification. The raw `WorkoutQueryService` read remains an implementation dependency in the detail view, but it can no longer publish a result that fails the query service's visibility check. This satisfies the original visibility-policy finding.
- **Second model session (P2)**: iOS 27 uses one typed tool call in the same model session that interprets the question. The `HealthQueryEvidence` actor validates the plan, consumes a one-attempt budget before suspension, executes one read, and retains the exact result. The older OS path still uses a planning response followed by one direct read. No redundant second session remains.
- **Production routing ownership (P2)**: `HealthQueryServiceRouting` moved to `DUNE/App/Intents/HealthQueryNavigation.swift`. `HealthQueryUITestFixture.swift` is now a DEBUG-only fixture implementation.
- **View cohesion (P3)**: The former 605-line file was split into view, ViewModel, result card, record detail, formatting extension, and snippet view. Each now has a distinct responsibility. The unused Spotlight writer and its view-side cleanup call were removed.

No new architecture finding was identified in those fixes. This was a read-only source review; I did not run builds or tests. The parent run reports a generic iOS build and 60 related unit tests passing. Vision target build remains unverified due to existing, unchanged Watch bedtime reminder type errors recorded in `.codex-checks/failures/siri-vision-baseline-errors.log`.

### [P2] Record detail bypasses the query boundary for HealthKit
- **File**: `DUNE/Presentation/HealthQuery/HealthQueryView.swift:585`
- **Principle**: Dependency inversion / single read boundary
- **Trigger**: Open a HealthKit workout from a query result, especially after the result has aged or the workout was tombstoned.
- **Issue**: `HealthQueryRecordDetailView` creates `WorkoutQueryService(manager: .shared)` and fetches HealthKit directly. This bypasses the injected `HealthQuerying` service used by the rest of this feature, including its protected-data guard, tombstone filter, and test fixture. The view can therefore resolve a record using different visibility rules from the result that presented the link.
- **Suggested fix**: Route record resolution through an injected read service that applies the same visibility policy, then pass the resolved detail DTO or approved record to the detail view. Keep the direct SwiftData lookup in the View only if that remains the established model-context ownership rule.

### [P2] Verified query depends on a second model session to execute
- **File**: `DUNE/Data/Services/HealthQueryAssistant.swift:68`
- **Principle**: Separation of concerns / reliability of the data path
- **Trigger**: Ask a supported health question on iOS 27 after the planning model has produced a validated request.
- **Issue**: The dynamic profile makes a second language model call solely to invoke `HealthQueryEvidenceTool`, which calls `queryService.execute(request)` and stores the result in an actor. No model interpretation of returned facts is used. A failed or omitted tool call now turns a valid, source-backed request into an unavailable answer, while older OS versions execute the service directly.
- **Suggested fix**: Execute the validated request directly, as the older-OS branch already does. Retain the profile/tool only if it supports an actual model decision that cannot be made before the read; keep the exact source-backed result as the returned answer.

### [P2] Production composition is defined in a UI test fixture file
- **File**: `DUNE/Presentation/HealthQuery/HealthQueryUITestFixture.swift:4`
- **Principle**: Layer ownership / cohesion
- **Trigger**: Either production entry point constructs `HealthQueryView` through `HealthQueryServiceRouting.current()` (`ContentView` and `HealthDataQASheet`).
- **Issue**: The release routing function lives beside synthetic test records in Presentation, references the concrete Data singleton, and becomes a required production dependency of both entry points. This moves composition policy out of App and couples normal navigation to a fixture source file.
- **Suggested fix**: Place production service selection in the App composition root or an injected environment dependency. Keep the fixture implementation and debug override in a separate test-only file.

### [P3] The new query view file combines unrelated responsibilities
- **File**: `DUNE/Presentation/HealthQuery/HealthQueryView.swift:1`
- **Principle**: Cohesion / maintainability
- **Trigger**: A change to query formatting, ViewModel behavior, result presentation, or record navigation.
- **Issue**: This 605-line file contains domain-enum display mappings, metric formatting, an observable ViewModel, the query screen, a full result renderer, record relookup/navigation, and preview wiring. These pieces have different change drivers and the record-detail section already imports SwiftData and concrete data services into the same file as display formatting.
- **Suggested fix**: Separate the ViewModel, result card, and record detail into feature files; put enum/unit display mapping with the feature's presentation formatting code.
