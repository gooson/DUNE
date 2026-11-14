---
tags: [foundation-models, evaluations, swift-testing, health-data-qa, workout-template, ai-safety]
date: 2026-10-14
category: testing
status: implemented
---

# Foundation Models feature evaluations

## Problem

HealthDataQAService and AIWorkoutTemplateGenerator had deterministic unit tests for summary construction, prompt parsing, and template resolution, but no repeatable way to measure actual model responses across languages and safety cases. Q&A also used `Locale.current` directly, preventing one run from exercising Korean, English, and Japanese instructions on the same host.

The installed Xcode 27 / iOS 27 SDK has no `Evaluations` framework module in its platform SDKs or Swift toolchain. The WWDC26 sessions describe an `Evaluations` API, but importing it in this project would not compile against the installed SDK. The implementation therefore uses the available Swift Testing framework and does not claim compatibility with the uninstalled API.

## Solution

- Added a versioned synthetic seed dataset with nine Q&A samples and nine workout-template prompts, balanced across Korean, English, and Japanese.
- Added conservative rule-based metrics for answer language, grounding to synthetic workout counts, missing-data abstention, medical overclaim refusal, catalog membership, duplicate slots, normalized set/repetition bounds, and cardio defaults. Contradictory quantities and hedged treatment claims have negative examples.
- Medical safety must pass all three locale cases. Live answers also receive a separate structured semantic judgment for diagnosis and treatment advice, and any judgment failure fails that case. Workout grounding checks count claims while allowing the question's 14-day window and authorized workout duration in an answer.
- Added live tests that call the production Q&A and template-generation services. The normal `DUNETests` scheme always runs deterministic corpus/scorer checks and leaves live tests disabled. The `DUNEAIEvaluations` scheme explicitly sets `DUNE_RUN_LIVE_AI_EVALUATIONS=1` for the two model-backed tests. Those tests fail if the model reports available but its assets cannot produce a probe answer, or if Q&A falls back.
- Added a locale identifier provider to `HealthDataQAService`, defaulting to `Locale.current.identifier` to preserve existing behavior.
- Added `scripts/evaluate-ai-features.sh`, which runs only the evaluation suite, participates in the shared simulator test lock, and checks the result bundle to require both live model tests to pass.

Run on an Apple Intelligence-capable iOS 27 destination:

```bash
scripts/evaluate-ai-features.sh
```

The standard unit runner selects a worktree-owned iOS simulator and applies the local resource/deadline budget. Use `scripts/evaluate-ai-features.sh --dry-run` to inspect the exact command. Do not direct it at a public simulator by name. The default unit suite verifies the six bodyweight/cardio production builder paths, nine positive Q&A scorer fixtures, adversarial negative fixtures, and locale/safety/fallback seams without calling Foundation Models. The opt-in command requires both live methods to execute and pass. An unavailable model, missing assets, generation/fallback error, failed semantic judge, skipped test, or missing result makes the command fail; thresholds and test identifiers are unchanged.

## Prevention

- Keep corpus entries synthetic and stable; never add real HealthKit records or user prompts.
- Retain separate fixture/scorer coverage and live model evaluation. Model availability, language, and outputs are not deterministic unit-test inputs. Never use the normal unit scheme's skipped live tests as positive model evidence.
- When the installed SDK provides the Evaluations framework, migrate to its documented `Evaluation`, `ModelSample`, `ArrayLoader`, `Metric`, `Evaluator`, and Swift Testing `.evaluates` integration only after verifying the actual module and signatures locally.
- Keep the custom scorer focused on measurable properties. Language/script, phrase checks, and model-based semantic judgment are regression signals, not a substitute for human review of medical safety. A false positive remains possible.

## Lessons Learned

WWDC26 session 241 describes the Evaluations framework and the `fm` CLI; session 298 shows the Swift evaluation APIs and recommends starting with a small focused dataset. The local Xcode installation can lag session material, so verify SDK module availability before adopting examples. Sources: [WWDC26 session 241](https://developer.apple.com/videos/play/wwdc2026/241/) and [WWDC26 session 298](https://developer.apple.com/videos/play/wwdc2026/298/).
