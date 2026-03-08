---
tags: [visionos, speech, parser, localization, testing]
category: architecture
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Vision/VisionVoiceWorkoutCommandParser.swift
  - DUNE/Presentation/Vision/VisionVoiceWorkoutEntryViewModel.swift
  - DUNEVision/Presentation/Activity/VisionVoiceWorkoutEntryCard.swift
  - DUNEVision/Presentation/Activity/VisionTrainView.swift
  - DUNE/project.yml
  - DUNETests/VisionVoiceWorkoutCommandParserTests.swift
  - DUNETests/VisionVoiceWorkoutEntryViewModelTests.swift
  - Shared/Resources/Localizable.xcstrings
  - todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md
related_solutions:
  - docs/solutions/architecture/2026-03-07-vision-pro-exercise-form-guide.md
  - docs/solutions/architecture/2026-03-07-vision-pro-multi-window-dashboard.md
---

# Solution: Vision Pro Voice Workout Entry Foundation

## Problem

`020` TODO의 F3 Voice-First Workout Entry는 남아 있었지만, visionOS `Train` 탭에는 음성 입력을 받아 운동 초안으로 바꾸는 최소 흐름조차 없었다. 반면 full save flow, SwiftData exercise persistence, SharePlay는 아직 준비되지 않아 한 번에 전부 구현하기 어려웠다.

### Symptoms

- Vision Pro에서 음성이나 텍스트로 workout command를 빠르게 초안화할 surface가 없었다.
- 자연어 transcript를 exercise library 기반 draft로 바꾸는 parser가 없었다.
- 새 문자열이 localized response를 반환하는데 테스트는 영어 literal을 가정해 회귀가 쉽게 깨질 수 있었다.

### Root Cause

고급 입력 기능을 full persistence scope로만 보고 있었기 때문에, 지금 바로 ship 가능한 foundation과 후속 capability 의존 영역이 분리되지 않았다. 그 결과 speech permission, parser, preview UI 같은 공통 기반도 비어 있었다.

## Solution

이번 배치에서는 F3를 foundation scope로 재정의했다. `VisionVoiceWorkoutCommandParser`가 transcript에서 exercise, reps, weight, duration, distance를 추출하고, `VisionVoiceWorkoutEntryViewModel`이 speech authorization과 transcript lifecycle을 관리하며, `VisionVoiceWorkoutEntryCard`가 `Train` 탭에서 draft preview를 제공하도록 연결했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Vision/VisionVoiceWorkoutCommandParser.swift` | Added metric extraction, exercise matching, inference notes, and Swift 6-safe explicit parsing branches | speech transcript를 shared domain draft로 변환하는 core logic 확보 |
| `DUNE/Presentation/Vision/VisionVoiceWorkoutEntryViewModel.swift` | Added speech auth handling, listening state, parser integration, and manual fallback copy | voice capture와 preview state를 testable shared model로 분리 |
| `DUNEVision/Presentation/Activity/VisionVoiceWorkoutEntryCard.swift` | Added transcript input, start/stop listening action, feedback card, and draft preview chips | visionOS `Train` 탭에 foundation UI 노출 |
| `DUNEVision/Presentation/Activity/VisionTrainView.swift` | Inserted quick entry card ahead of existing exercise guide | 새 foundation을 기존 activity flow 안에 실제 배치 |
| `DUNE/project.yml` | Added microphone/speech usage descriptions and `Speech.framework` to `DUNEVision` | speech capture capability wiring |
| `Shared/Resources/Localizable.xcstrings` | Added voice-entry UI and parser feedback copy in ko/ja | voice foundation도 existing localization policy를 따르도록 보장 |
| `DUNETests/VisionVoiceWorkoutCommandParserTests.swift` | Added parser coverage and localized expectation updates | parser inference/failure behavior 회귀 방지 |
| `DUNETests/VisionVoiceWorkoutEntryViewModelTests.swift` | Added speech authorization, transcript update, review flow coverage | voice entry state machine 회귀 방지 |
| `todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md` | Marked F3 foundation progress and deferred persistence scope | roadmap 상태를 실제 ship 범위와 일치시킴 |

### Key Code

```swift
if let durationMatch,
   let durationUnitToken = Self.capture(group: 2, from: remainingTranscript, match: durationMatch),
   let durationValue {
    durationSeconds = Self.durationSeconds(for: durationValue, unitToken: durationUnitToken)
} else {
    durationSeconds = nil
}
```

```swift
#expect(viewModel.infoMessage == String(localized: "Listening..."))
```

## Prevention

voice feature처럼 scope가 큰 작업은 `capture -> parse -> preview` foundation과 `persist -> sync -> social` 확장 단계를 먼저 나눠야 한다. 또 `String(localized:)`를 반환하는 production code 주변 테스트는 locale-dependent literal 대신 동일한 localized key를 기대값으로 사용해야 한다.

### Checklist Addition

- [ ] transcript parser가 `Optional.flatMap` 추론에 기대지 않고 Swift 6에서도 안정적으로 컴파일되는지 확인한다.
- [ ] localization-aware feature 테스트는 영어 문자열 literal이 아니라 `String(localized:)` 기대값을 사용한다.
- [ ] capability-heavy roadmap item은 foundation scope와 persistence/social scope를 TODO에 분리 기록한다.

### Rule Addition (if applicable)

새 rule 추가는 필요 없었다. 기존 `localization.md`, `testing-required.md`, `swift-layer-boundaries.md` 범위 안에서 정리 가능했다.

## Lessons Learned

Vision Pro 고급 입력 기능은 full save flow가 없어도 foundation UI를 먼저 ship할 수 있다. parser, authorization, localized preview를 shared layer에 먼저 고정해 두면 이후 persistence와 SharePlay 확장은 훨씬 작은 변경으로 이어진다.
