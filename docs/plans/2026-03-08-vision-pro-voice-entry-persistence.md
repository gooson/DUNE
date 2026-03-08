---
topic: vision-pro-voice-entry-persistence
date: 2026-03-08
status: draft
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-08-vision-pro-voice-workout-entry-foundation.md
  - docs/solutions/security/2026-02-15-input-validation-swiftdata.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-vision-pro-production-roadmap.md
---

# Implementation Plan: Vision Pro Voice Entry Persistence

## Context

Vision Pro `Train` 탭의 voice quick entry는 transcript를 `VisionVoiceWorkoutDraft`로 파싱하고 preview까지 보여주지만,
아직 workout history 저장은 막혀 있다. `todos/023-in-progress-p2-vision-phase4-remaining.md`에서 남은 F3 범위 중
가장 바로 ship 가능한 조각은 이 draft를 `ExerciseRecord`로 변환해 SwiftData에 저장하는 흐름이다.

## Requirements

### Functional

- voice draft를 workout history에 저장할 수 있어야 한다.
- 저장은 기존 레이어 규칙을 따라 ViewModel이 validated `ExerciseRecord`를 만들고, View가 `modelContext.insert`를 수행해야 한다.
- strength/cardio draft 모두 기존 `ExerciseRecord`/`WorkoutSet` 구조와 일관된 형태로 매핑해야 한다.
- 저장 성공/실패/중복 저장 불가 상태를 Vision Pro 카드에서 사용자에게 확인시켜야 한다.
- 관련 TODO/solution 문서를 최신 범위에 맞게 갱신해야 한다.

### Non-functional

- DUNEVision target에 persistence scope를 넓게 끌어오지 않고 기존 shared model만 재사용한다.
- 새 사용자 대면 문자열은 `Shared/Resources/Localizable.xcstrings`에 en/ko/ja 모두 추가한다.
- 로직 변경에는 `DUNETests` 유닛 테스트를 추가한다.

## Approach

`VisionVoiceWorkoutEntryViewModel`에 `draft -> ExerciseRecord` 변환 책임을 추가한다.
strength 계열은 single completed `WorkoutSet`으로 `weight/reps`를 저장하고,
cardio 계열은 `duration/distance/reps(intensity는 없음)`를 exercise input type에 맞춰 기록한다.
실제 persistence는 `VisionVoiceWorkoutEntryCard`가 `@Environment(\.modelContext)`로 insert 한 뒤
`didFinishSaving()`에 해당하는 후처리를 ViewModel에 알려 주는 기존 패턴을 따른다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| ViewModel이 `ExerciseRecord` 생성, View가 insert | 기존 `WorkoutSessionViewModel`/input-validation 규칙과 일치, 테스트 용이 | 카드 쪽에 저장 호출 wiring 필요 | 채택 |
| ViewModel이 SwiftData 직접 insert | 구현이 짧아 보임 | `swift-layer-boundaries.md` 위반, 테스트 어려움 | 기각 |
| voice save를 별도 service/use case로 분리 | 향후 확장성 | 현재 scope 대비 과함, 기존 모델 조합으로 충분 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-08-vision-pro-voice-entry-persistence.md` | new | 이번 배치 계획 문서 |
| `DUNE/Presentation/Vision/VisionVoiceWorkoutEntryViewModel.swift` | modify | validated record 생성/저장 상태 관리 추가 |
| `DUNEVision/Presentation/Activity/VisionVoiceWorkoutEntryCard.swift` | modify | 저장 버튼 + modelContext insert + feedback 연결 |
| `DUNETests/VisionVoiceWorkoutEntryViewModelTests.swift` | modify | record 생성/상태 전이 테스트 추가 |
| `Shared/Resources/Localizable.xcstrings` | modify | 저장 관련 copy 추가 |
| `todos/023-in-progress-p2-vision-phase4-remaining.md` | modify | F3 잔여 범위 축소 메모 반영 |
| `docs/solutions/architecture/2026-03-08-vision-pro-voice-entry-persistence.md` | new | 해결책 문서 |

## Implementation Steps

### Step 1: Voice draft save model 확장

- **Files**: `VisionVoiceWorkoutEntryViewModel.swift`
- **Changes**:
  - save-in-progress / save-complete 상태를 추가한다.
  - `draft` 유무와 저장 상태를 바탕으로 저장 가능 여부를 계산한다.
  - `VisionVoiceWorkoutDraft`를 `ExerciseRecord`/`WorkoutSet`으로 변환하는 validated helper를 추가한다.
- **Verification**: strength/cardio draft가 각각 single record로 변환되고, 저장 후 중복 저장이 차단된다.

### Step 2: visionOS card에 저장 액션 연결

- **Files**: `VisionVoiceWorkoutEntryCard.swift`, `Localizable.xcstrings`
- **Changes**:
  - 저장 버튼과 성공/실패 피드백을 추가한다.
  - `@Environment(\.modelContext)`에서 record를 insert 하고 후처리를 호출한다.
  - 기존 “preview only” copy를 실제 저장 가능 상태에 맞게 교체한다.
- **Verification**: draft가 있을 때만 저장 버튼이 활성화되고, 저장 후 success feedback이 노출된다.

### Step 3: 테스트와 roadmap 문서 정리

- **Files**: `VisionVoiceWorkoutEntryViewModelTests.swift`, `todos/023-in-progress-p2-vision-phase4-remaining.md`
- **Changes**:
  - record 생성 매핑과 저장 후 상태 reset/confirmation을 검증한다.
  - TODO 메모를 현재 기준으로 갱신해 남은 F3 범위를 audio feedback 중심으로 좁힌다.
- **Verification**: targeted tests 통과, TODO가 실제 ship 범위를 반영한다.

## Edge Cases

| Case | Handling |
|------|----------|
| draft가 없는 상태에서 저장 시도 | 버튼 비활성화로 차단 |
| strength draft에 reps만 있고 weight 없음 | single set record 생성, weight는 nil 허용 |
| cardio draft가 duration만 있고 distance 없음 | `durationDistance` 규칙에 맞춰 duration-only record 저장 허용 |
| 저장 직후 transcript를 다시 편집 | draft/saved state를 초기화해 새 review/save 사이클 시작 |
| 동일 draft를 연속 저장 | save complete 상태를 별도로 두어 중복 저장 차단 |

## Testing Strategy

- Unit tests: `VisionVoiceWorkoutEntryViewModelTests`에 strength/cardio record 생성과 save lifecycle 검증 추가
- Integration tests: 없음. SwiftData insert는 view wiring 수준이라 targeted build/test로 커버
- Manual verification: Vision Pro `Train` 탭에서 draft review 후 save 버튼 노출/비활성/성공 메시지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| voice draft를 단일 `WorkoutSet`으로 저장하는 규칙이 기존 session 분석과 어긋날 수 있음 | medium | medium | 기존 `ExerciseRecord`/`WorkoutSet` 필드만 사용하고 `WorkoutSessionViewModel` 매핑과 맞춘다 |
| DUNEVision target의 SwiftData runtime wiring 누락 | low | high | 이미 shared persistence model이 visionOS target에 포함돼 있는지 build로 확인한다 |
| 저장 후 상태 reset이 과도해 transcript 재사용 UX가 나빠질 수 있음 | medium | low | transcript는 유지하고 draft/success flag만 명시적으로 관리한다 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: parser와 preview foundation, shared persistence model, 기존 `createValidatedRecord -> modelContext.insert` 패턴이 이미 있어 구현 자체는 명확하다. 다만 visionOS target에서 실제 insert/build 검증이 필요하다.
