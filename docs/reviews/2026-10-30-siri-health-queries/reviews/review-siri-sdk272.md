# Siri health queries: installed Xcode 27.2 SDK audit

2026-10-30. Read-only source/API audit of HEAD `19754ce6`. Installed toolchain: Xcode 27.2 (27B52), Swift compiler 6.4.2, iPhoneSimulator27.2.sdk. No source edit, build, test, simulator run, or Siri invocation was performed for this audit.

## Result

**Required migration from the inspected 27.2 declarations: none identified.** Every Siri/FoundationModels symbol used by the targeted implementation is still declared publicly with an availability compatible with its call site. This is an API-presence/availability conclusion, not a runtime or 27.1-to-27.2 binary diff.

## Inspected declarations and call sites

SDK paths below are relative to `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator27.2.sdk/System/Library/Frameworks/`; line numbers refer to the `arm64-apple-ios-simulator.swiftinterface` in each framework's `Modules/<Framework>.swiftmodule/` directory.

| Behavior | Current code | SDK evidence | Decision |
|---|---|---|---|
| Dynamic evidence profile and per-session state | `DUNE/Data/Services/HealthQueryAssistant.swift:46-64,228-270` | `FoundationModels`: `DynamicProfile`/`Profile` 820-845, `init(profile:)` 913-918, profile modifiers 960-980, `SessionProperty` 1035-1045, `SessionPropertyEntry` 1080-1099. These profile APIs are marked iOS 27.0, not 27.2. | Keep the `#if compiler(>=6.4)` and `#available(iOS 27.0, …)` branch; no 27.2 rewrite needed. |
| One required tool attempt, then disallowed | `HealthQueryAssistant.swift:235-268` | `FoundationModels`: `Tool` 3225-3251; `ToolCallingMode.required`/`.disallowed` 3456-3481; `.toolCallingMode` 979. | Declarations remain available. The SDK declaration alone cannot prove model obeys “exactly once”; the actor's `hasAttempted` budget at 211-224 remains the enforcement. |
| Availability and locale for on-device model | `HealthQueryAssistant.swift:17-32` | `FoundationModels`: `SystemLanguageModel.default` and synchronous `supportsLocale(_:)` 388-402. | No required change. |
| Long running work/progress | `DUNE/App/Intents/HealthQueryIntent.swift:167-185,229-253,297-302` | `AppIntents`: `LongRunningIntent` and `performBackgroundTask` 7720-7728, both iOS 27.0; `ProgressReportingIntent` 7740-7750. | Current compiler and runtime gates are consistent; no 27.2-only API required. |
| Invoking Siri locale | `HealthQueryIntent.swift:194-199,261-266`; `DUNE/Domain/Models/HealthQueryLocalization.swift:3-6` | `AppIntents`: `AppIntent.systemContext` 9158-9164; `IntentSystemContext.locale` 9166-9172, iOS 27.0. | Capturing locale before background work and propagating via TaskLocal remains valid. |
| Search handoff | `DUNE/App/Intents/HealthQueryEntities.swift:109-131` | `AppIntents`: `.system.searchInApp` 3053-3067, iOS 27.0; older `.system.search` is deprecated with replacement text at 3047-3051; `ShowInAppSearchResultsIntent` 14878-14889. | Current schema is the replacement already. |
| Authentication, execution target, snippet/dialog result | `HealthQueryIntent.swift:132-162,188-191,213-224,255-258,276-295`; `DUNE/App/Intents/DUNEShortcuts.swift:76-95` | `AppIntents`: `authenticationPolicy` and `allowedExecutionTargets` requirements 7224-7229; `.requiresLocalDeviceAuthentication` 7284-7288; `SnippetIntent` 7779-7784; `ShowsSnippetIntent` 8604-8609; result overload combining value/dialog/snippet 8680-8683. | No removed overload or 27.2 availability mismatch found. Protected-data checks and transient answer cache remain app-specific safeguards. |

## Explicitly 27.2 APIs found nearby

`FoundationModels` adds public data attachment/entry support such as `DataEntryRepresentable` (1482), `LanguageModel.supportsDataAttachmentType`/`supportsDataEntryType` (1495-1505), `Transcript.DataAttachment` (2511 onward), and `Transcript.DataEntry` (2768 onward). `AppIntents` adds `AssistantSchemaEnum.caseDisplayRepresentations` (6121), importing-only `IntentValueRepresentation` initializers (6758, 6765), and `_IntentValueRepresentable` parameter initializer overloads (9370 onward). The current health question is a `String` with typed tool arguments and an `AppEntity` result, with no data attachment, custom model executor, AssistantSchemaEnum, or intent value representation. These declarations supply **no necessary change** to this flow. If any are adopted later, guard calls with `#available(iOS 27.2, *)` because `DUNE/project.yml:6` still targets iOS 27.0.

## Scope and limits

- Only Xcode 27.2 is installed under `/Applications/Xcode.app`; `iPhoneSimulator.sdk` points to the same installed SDK. The 27.1 SDK/interface was unavailable, so this audit cannot identify precise 27.1-to-27.2 additions/removals or behavior changes. “Still present in 27.2” is the supported claim.
- The `Intents.framework` in this SDK exposes Objective-C headers, with no Swift interface to compare; this flow imports `AppIntents`, not `Intents`.
- No compiler/build or device execution was part of this subtask. The parent task's separate build and live Siri checks must establish compile/runtime behavior and feature availability on supported devices.

## Supplemental SDK check: other Siri-adjacent surfaces

- **AssistantSchemas health/fitness domain:** The installed `AppIntents` interface contains no public `AssistantSchemas` health, fitness, or workout schema. The only `workout` match is the separate `StartWorkoutIntent.workoutStyle` requirement at line 16645; that is an action schema for starting workouts, not a read-only health query schema. The 27.2 `AssistantSchemaEnum.caseDisplayRepresentations` default at line 6121 does not supply a domain or change the existing `AppEnum` declarations in `HealthQueryIntent.swift:6-37`.
- **SpotlightSearchTool:** `_CoreSpotlight_FoundationModels` declares `SpotlightSearchTool` and `SearchSource` for iOS 27.0 at lines 9-43, 44-57, 329-383. Its public configuration supports `.coreSpotlight` and `.files`, `customStages`, a guide, and maximum response size. `CoreSpotlightSource` at lines 12-21 exposes a searchable-index delegate, but the public configuration shows no dedicated custom index identifier or protected-data authorization contract. This is a 27.0 API present in 27.2, not evidence of a new 27.2 protected memo search feature. Substituting it for the app's typed `HealthQueryService` would require separate indexing, privacy, and result-validation design; no SDK-driven change is warranted.
- **Siri speech voice:** `AVFAudio.framework/Headers/AVSpeechSynthesis.h:112-153` exposes the general `AVSpeechSynthesisVoice` enumeration, language, identifier, quality, gender, and voice traits. No public Siri-specific voice selection declaration was found there. The current intent's `ProvidesDialog` lets the system render the spoken reply; adding app-side speech synthesis is not indicated by this SDK audit.
