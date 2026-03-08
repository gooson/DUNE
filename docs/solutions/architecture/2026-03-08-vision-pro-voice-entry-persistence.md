---
tags: [visionos, swiftdata, speech, persistence, testing]
category: architecture
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Vision/VisionVoiceWorkoutEntryViewModel.swift
  - DUNEVision/Presentation/Activity/VisionVoiceWorkoutEntryCard.swift
  - DUNEVision/App/DUNEVisionApp.swift
  - DUNEVision/App/VisionExerciseHistoryContainerFactory.swift
  - DUNE/project.yml
  - DUNETests/VisionVoiceWorkoutEntryViewModelTests.swift
  - Shared/Resources/Localizable.xcstrings
  - todos/023-in-progress-p2-vision-phase4-remaining.md
related_solutions:
  - docs/solutions/architecture/2026-03-08-vision-pro-voice-workout-entry-foundation.md
  - docs/solutions/architecture/2026-03-08-vision-pro-shareplay-workout-board-foundation.md
---

# Solution: Vision Pro Voice Quick Entry Persistence

## Problem

`Train` 탭의 voice quick entry는 transcript를 draft preview까지는 만들 수 있었지만, 실제 운동 기록으로 저장할 수는 없었다. 그래서 Phase 5C의 F3가 foundation에서 멈춘 상태였고, Vision Pro 안에서 빠르게 한 건을 남기는 핵심 가치가 비어 있었다.

### Symptoms

- 사용자는 Vision Pro에서 음성으로 운동을 입력해도 preview만 보고 끝나야 했다.
- draft를 `ExerciseRecord`/`WorkoutSet`으로 바꾸는 공용 매핑이 없어 저장 경로를 붙일 수 없었다.
- DUNEVision target에는 exercise history용 SwiftData schema/container가 없어 persistence wiring이 불완전했다.

### Root Cause

foundation 단계에서 speech capture, parser, preview UI만 먼저 ship했고, persistence는 iOS exercise stack과 연결될 별도 scope로 남겨 두었다. 그 결과 visionOS에서 사용할 최소 저장 경로와 target wiring이 비어 있었다.

## Solution

이번 배치에서는 draft preview 다음 단계만 좁게 연결했다. `VisionVoiceWorkoutEntryViewModel`이 reviewed draft를 검증된 `ExerciseRecord`로 변환하고, `VisionVoiceWorkoutEntryCard`가 이를 SwiftData context에 insert하며, DUNEVision app은 exercise history 전용 container를 별도로 주입한다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Vision/VisionVoiceWorkoutEntryViewModel.swift` | Added save state, reviewed-draft validation, and draft-to-record/set mapping | preview-only flow를 single-entry persistence flow로 확장 |
| `DUNEVision/Presentation/Activity/VisionVoiceWorkoutEntryCard.swift` | Added save CTA and `modelContext` insertion path | visionOS UI에서 실제 저장 액션 제공 |
| `DUNEVision/App/VisionExerciseHistoryContainerFactory.swift` | Added exercise history-specific SwiftData container factory | mirrored snapshot store와 분리된 exercise history persistence 확보 |
| `DUNEVision/App/DUNEVisionApp.swift` | Injected history model container with recovery/fallback behavior | voice quick entry가 app root에서 SwiftData context를 받을 수 있게 연결 |
| `DUNE/project.yml` | Added exercise persistence models to DUNEVision target sources | visionOS target이 history model types를 실제로 빌드하도록 보장 |
| `DUNETests/VisionVoiceWorkoutEntryViewModelTests.swift` | Added strength/cardio mapping and validation coverage | reviewed draft 저장 규칙과 단위 변환 회귀 방지 |
| `Shared/Resources/Localizable.xcstrings` | Updated save-capable copy and feedback strings | preview-only copy를 실제 동작과 맞춤 |
| `todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md` | Narrowed remaining F3 scope to audio-first enhancements | roadmap 상태를 ship 결과와 일치시킴 |

### Key Code

```swift
func createValidatedRecord() -> ExerciseRecord? {
    guard !isSaving, !isDraftSaved else { return nil }
    guard let draft else {
        errorMessage = String(localized: "Review the voice draft before saving it.")
        return nil
    }

    isSaving = true
    errorMessage = nil
    return buildRecord(from: draft)
}
```

```swift
static let schema = Schema([ExerciseRecord.self, WorkoutSet.self])
```

## Prevention

voice feature처럼 foundation과 persistence가 나뉘는 작업은 preview ship 직후에 “single-entry save” 같은 최소 후속 범위를 따로 분리해 두는 편이 좋다. 또 visionOS 전용 저장 요구가 생기면 기존 mirror store와 섞지 말고 schema 목적별 container를 분리해야 migration 범위를 제어할 수 있다.

### Checklist Addition

- [ ] preview-only UI 문구가 실제 저장 가능 상태와 어긋나지 않는지 확인한다.
- [ ] speech draft를 persistence model로 매핑할 때 exercise input type별 weight/distance/duration 규칙을 테스트로 고정한다.
- [ ] visionOS에서 새 SwiftData persistence를 추가할 때 mirrored snapshot store와 write store를 분리할지 먼저 검토한다.

### Rule Addition (if applicable)

새 rule 추가는 필요 없었다. 기존 `swift-layer-boundaries.md`, `testing-required.md`, `localization.md` 범위에서 해결 가능했다.

## Lessons Learned

Vision Pro voice entry는 full workout editor가 없어도 single-entry save만 연결하면 사용자 가치가 크게 올라간다. 핵심은 parser draft를 shared persistence model로 바꾸는 얇은 매핑 계층과, 읽기 전용 mirror data와 쓰기 전용 history data를 분리한 container 설계였다.
