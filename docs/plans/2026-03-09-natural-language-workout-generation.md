---
topic: natural-language-workout-generation
date: 2026-03-09
status: draft
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-09-foundation-models-integration-pattern.md
  - docs/solutions/architecture/2026-03-08-on-device-prediction-features.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-apple-on-device-ml-sdk-research.md
---

# Implementation Plan: Natural Language Workout Generation

## Context

`todos/106-ready-p2-natural-language-workout-generation.md` asks for a Foundation Models powered flow that turns prompts like "today shoulder workout for 30 minutes" into an app-native workout template. The app already has:

- an exercise catalog backed by `exercises.json` via `ExerciseLibraryService`
- Foundation Models integration patterns in `AICoachingMessageService` and `FoundationModelReportFormatter`
- a persisted `WorkoutTemplate` model and a manual authoring surface in `TemplateFormView`

The missing piece is a generator that can search the exercise catalog, personalize from recent workout history, and convert the generated output into `TemplateEntry` values the existing template flow can save.

## Requirements

### Functional

- Generate a structured workout template from a natural language prompt using Foundation Models.
- Define `@Generable` output models for the generated workout template and exercise slots.
- Use Tool Calling to search the bundled exercise catalog so the model can resolve canonical app exercises.
- Provide recent workout history / recovery-oriented context to personalize the generated routine.
- Convert generated output into existing `WorkoutTemplate` / `TemplateEntry` data.
- Expose the flow from an existing template creation surface so a user can actually save the generated template.
- Show a clear fallback/error state when Foundation Models are unavailable or generation fails.

### Non-functional

- Keep `FoundationModels` imports inside Data layer code.
- Reuse existing template/exercise resolution helpers instead of adding a parallel persistence format.
- Add unit tests for new logic and changed behavior.
- Localize all new user-facing strings in `Shared/Resources/Localizable.xcstrings`.

## Approach

Add a Domain protocol plus request/response models for workout generation, implement the Foundation Models service in Data with a small catalog search tool, then wire it into `TemplateFormView` as an AI-assisted create flow. The UI should stay intentionally narrow: prompt input, generate action, loading/error state, and applying the generated template into the existing form fields.

This keeps the new AI-specific logic isolated while making the feature shippable without inventing a second template authoring UI.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| New standalone chat/sheet flow for AI templates | Cleaner dedicated UX | More UI scope, more navigation/state work, slower to ship | Rejected |
| Service-only implementation without UI entry point | Smallest code change | User cannot actually use the feature from the app | Rejected |
| Add AI generation into existing `TemplateFormView` | Reuses persistence and editing flow, smallest shippable surface | Adds extra state to an already large view | Chosen |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Protocols/NaturalLanguageWorkoutGenerating.swift` | New | Domain-facing generation contract |
| `DUNE/Domain/Models/GeneratedWorkoutTemplate.swift` | New | Request/response models for generated templates |
| `DUNE/Data/Services/AIWorkoutTemplateGenerator.swift` | New | Foundation Models + Tool Calling implementation |
| `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift` | Edit | Add AI prompt UI, loading/error state, apply generated output |
| `DUNE/Presentation/Shared/Extensions/ExerciseRecord+Snapshot.swift` | New | Shared helper to convert records into `ExerciseRecordSnapshot` |
| `DUNETests/AIWorkoutTemplateGeneratorTests.swift` | New | Prompt/context/tool-result conversion tests |
| `DUNETests/TemplateWorkoutTests.swift` | Edit | Verify generated template entry conversion constraints if needed |
| `Shared/Resources/Localizable.xcstrings` | Edit | Add new en/ko/ja strings |

## Implementation Steps

### Step 1: Add generation contract and generated workout models

- **Files**: `DUNE/Domain/Protocols/NaturalLanguageWorkoutGenerating.swift`, `DUNE/Domain/Models/GeneratedWorkoutTemplate.swift`
- **Changes**:
  - Define a request model containing the user prompt and recent workout snapshots.
  - Define a generated template response with template name, estimated minutes, and resolved exercise slots.
  - Keep the contract `Sendable` and free of `FoundationModels`.
- **Verification**: New types compile and remain usable from Presentation/Data layers.

### Step 2: Implement Foundation Models workout generator

- **Files**: `DUNE/Data/Services/AIWorkoutTemplateGenerator.swift`
- **Changes**:
  - Add `@Generable` models for model output.
  - Add a `Tool` implementation that searches `ExerciseLibraryQuerying` and returns canonical matches.
  - Build a locale-aware prompt with user request plus compact recent-workout/recovery context.
  - Validate output, resolve exercises back to library definitions, and convert into generated template slots.
  - Gracefully fail for unavailable devices, empty output, or unresolved exercises.
- **Verification**: Unit tests cover prompt construction, context summarization, and slot-to-template conversion behavior.

### Step 3: Reuse existing template entry conversion path

- **Files**: `DUNE/Data/Services/AIWorkoutTemplateGenerator.swift`, `DUNE/Presentation/Exercise/TemplateExerciseResolver.swift` if needed
- **Changes**:
  - Convert resolved generated slots into `TemplateEntry` values using existing metadata patterns.
  - Clamp set/rep values to existing template limits.
  - Ensure cardio/unsupported shapes degrade safely instead of creating broken template entries.
- **Verification**: Tests confirm generated slots become valid `TemplateEntry` values.

### Step 4: Wire AI generation into template creation UI

- **Files**: `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift`, `DUNE/Presentation/Shared/Extensions/ExerciseRecord+Snapshot.swift`
- **Changes**:
  - Add prompt input and generate action for create mode.
  - Query recent `ExerciseRecord`s, map them to `ExerciseRecordSnapshot`s, and pass them into the generator.
  - Reflect loading/error state and apply generated template name + entries back into the existing form.
  - Keep save/edit semantics unchanged after generation.
- **Verification**: Build succeeds and the new create-mode flow compiles without changing edit-mode behavior.

### Step 5: Add tests and localization coverage

- **Files**: `DUNETests/AIWorkoutTemplateGeneratorTests.swift`, `DUNETests/TemplateWorkoutTests.swift`, `Shared/Resources/Localizable.xcstrings`
- **Changes**:
  - Add Swift Testing coverage for context aggregation, search-tool formatting, and template-entry conversion.
  - Add all new UI/error/loading strings to the shared string catalog for en/ko/ja.
- **Verification**: Targeted tests pass and localization review finds no leaked hard-coded strings.

## Edge Cases

| Case | Handling |
|------|----------|
| Foundation Models unsupported device/simulator | Disable or fail generation with localized fallback message |
| Model returns exercise name not in catalog | Resolve via tool results first, then fail safely if no canonical match exists |
| Model returns too many/few exercises | Clamp accepted count and require at least one valid entry |
| Model returns invalid set/rep values | Re-clamp to existing `TemplateEntry` bounds |
| Recent history is empty | Omit personalization details and generate from prompt alone |
| User is on detached HEAD during implementation | Create a feature branch before committing in Work phase |

## Testing Strategy

- Unit tests: `AIWorkoutTemplateGeneratorTests` for prompt/context assembly, resolution, and validation; existing template tests updated if conversion helpers change.
- Integration tests: `scripts/build-ios.sh` and targeted `DUNETests` execution for the new generator test file.
- Manual verification: open template creation flow, generate from a natural language prompt, confirm template name/entries populate, then save successfully.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Foundation Models tool-calling API details differ from assumptions | Medium | High | Validate against local SDK interface before coding |
| `TemplateFormView` grows too stateful | Medium | Medium | Keep generation state narrow and reuse existing save path |
| Localization catalog edits become inconsistent | Medium | Medium | Limit new strings and update xcstrings in the same change |
| Generated cardio routines do not map cleanly to current template model | Medium | Medium | Bias prompt toward strength/bodyweight template entries and degrade safely |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: Existing Foundation Models and template infrastructure cover most of the feature, but Tool Calling integration and localized string-catalog updates still carry implementation risk.
