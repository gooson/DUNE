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
- Added rule-based metrics for answer language, grounding to synthetic workout counts, missing-data abstention, medical overclaim refusal, catalog membership, duplicate slots, set/repetition bounds, and cardio defaults.
- Added live tests that call the production Q&A and template-generation services. They run only when `SystemLanguageModel.default.isAvailable`; fixture/scorer tests remain deterministic on any host.
- Added a locale identifier provider to `HealthDataQAService`, defaulting to `Locale.current.identifier` to preserve existing behavior.
- Added `scripts/evaluate-ai-features.sh`, which runs only the evaluation suite and participates in the shared simulator test lock.

Run on an Apple Intelligence-capable iOS 27 destination:

```bash
DAILVE_IOS_DESTINATION='platform=iOS Simulator,name=iPhone 17,OS=27.0' scripts/evaluate-ai-features.sh
```

The static suite verifies corpus coverage and scorer failure cases. A simulator without an available Foundation Model skips the live generation tests; that is not evidence that model quality passed.

## Prevention

- Keep corpus entries synthetic and stable; never add real HealthKit records or user prompts.
- Retain separate fixture/scorer coverage and live model evaluation. Model availability, language, and outputs are not deterministic unit-test inputs.
- When the installed SDK provides the Evaluations framework, migrate to its documented `Evaluation`, `ModelSample`, `ArrayLoader`, `Metric`, `Evaluator`, and Swift Testing `.evaluates` integration only after verifying the actual module and signatures locally.
- Keep the custom scorer focused on measurable properties. Language/script and refusal phrase checks are regression signals, not a substitute for human review of medical safety.

## Lessons Learned

WWDC26 session 241 describes the Evaluations framework and the `fm` CLI; session 298 shows the Swift evaluation APIs and recommends starting with a small focused dataset. The local Xcode installation can lag session material, so verify SDK module availability before adopting examples. Sources: [WWDC26 session 241](https://developer.apple.com/videos/play/wwdc2026/241/) and [WWDC26 session 298](https://developer.apple.com/videos/play/wwdc2026/298/).
