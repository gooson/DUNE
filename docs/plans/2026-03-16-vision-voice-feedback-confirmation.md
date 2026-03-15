---
topic: vision-voice-feedback-confirmation
date: 2026-03-16
status: draft
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-08-vision-pro-voice-workout-entry-foundation.md
  - docs/solutions/architecture/2026-03-08-vision-pro-voice-entry-persistence.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-vision-pro-production-roadmap.md
---

# Implementation Plan: Vision Voice Feedback Confirmation

## Context

`todos/023-in-progress-p2-vision-phase4-remaining.md`에서 Vision Pro F3의 남은 범위는 `audio/spatial feedback`, `richer editing`, `multilingual confirmation UX`로 좁혀져 있다. 현재 `VisionVoiceWorkoutEntryViewModel`과 `VisionVoiceWorkoutEntryCard`는 transcript 파싱과 single-entry 저장까지는 지원하지만, review/save 이후의 confirmation은 단일 텍스트 피드백에 머물러 있고 draft를 미세 조정하는 편집 경로도 약하다.

이번 배치에서는 RealityKit 기반 spatial audio나 SharedWorldAnchors 같은 capability-heavy 범위를 건드리지 않고, 이미 ship된 voice quick entry surface를 완성도 높은 후속 범위로 마무리한다.

## Requirements

### Functional

- review/save 이후에 사용자에게 locale-aware confirmation UX를 제공해야 한다.
- confirmation UX는 한국어/영어/일본어에서 자연스럽게 동작해야 한다.
- draft preview에서 reps/weight/duration/distance를 가볍게 조정할 수 있어야 한다.
- 음성 피드백은 transcription 중에는 끼어들지 않고, unsupported 환경에서는 조용히 fallback 해야 한다.

### Non-functional

- speech/TTS 로직은 protocol 뒤로 감춰 unit test에서 검증 가능해야 한다.
- `SwiftData` insert 책임은 계속 View 쪽에 두고, ViewModel은 state/validation만 담당해야 한다.
- 새 사용자 대면 문자열은 `Localizable.xcstrings`에 en/ko/ja로 등록해야 한다.

## Approach

`VisionVoiceWorkoutEntryViewModel`에 confirmation summary builder와 speech feedback dependency를 추가하고, `VisionVoiceWorkoutEntryCard`에는 parsed draft를 바로 미세 조정할 수 있는 lightweight editing controls를 붙인다. review/save의 핵심 메시지는 localized string template로 관리하고, TTS는 현재 locale 기준 voice를 우선 선택하되 unavailable이면 텍스트 피드백만 남긴다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| RealityKit spatial audio cue를 바로 도입 | visionOS 네이티브 감각이 강함 | scene wiring, asset choice, 실기기 검증이 필요해 이번 범위를 초과 | 기각 |
| full form editor(TextField 중심)로 draft 전체 편집 | 가장 유연한 편집 UX | validation/keyboard/layout 범위가 커지고 테스트 비용이 큼 | 기각 |
| quick adjust controls + locale-aware TTS confirmation | 현재 TODO의 남은 범위를 직접 줄이고 기존 구조를 재사용 가능 | 정교한 spatial audio는 후속 TODO로 남음 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Vision/VisionVoiceWorkoutEntryViewModel.swift` | modify | confirmation summary, TTS dependency, lightweight draft editing state/action 추가 |
| `DUNEVision/Presentation/Activity/VisionVoiceWorkoutEntryCard.swift` | modify | review/save UX copy 갱신, draft metric quick adjust UI 추가 |
| `DUNETests/VisionVoiceWorkoutEntryViewModelTests.swift` | modify | confirmation summary/TTS trigger/edit action 회귀 테스트 추가 |
| `Shared/Resources/Localizable.xcstrings` | modify | confirmation/editing 관련 en/ko/ja 문자열 추가 |
| `todos/023-in-progress-p2-vision-phase4-remaining.md` | modify | 이번 배치로 줄어든 F3 범위를 반영 |
| `todos/*vision-voice-*.md` | add or modify | 이번 `/run` 대상 TODO를 별도 기록하고 완료 처리 |

## Implementation Steps

### Step 1: Add locale-aware confirmation feedback

- **Files**: `VisionVoiceWorkoutEntryViewModel.swift`, `VisionVoiceWorkoutEntryViewModelTests.swift`, `Localizable.xcstrings`
- **Changes**:
  - `AVSpeechSynthesizer` 기반 speaker protocol과 기본 구현을 추가한다.
  - review/save 시 draft summary를 locale-aware message로 구성한다.
  - transcription 중에는 speech feedback를 생략하고, locale voice 미존재 시 텍스트만 유지한다.
- **Verification**:
  - ViewModel test에서 review/save 후 info message와 speaker 호출 내용을 검증한다.

### Step 2: Add lightweight draft editing

- **Files**: `VisionVoiceWorkoutEntryViewModel.swift`, `VisionVoiceWorkoutEntryCard.swift`, `VisionVoiceWorkoutEntryViewModelTests.swift`
- **Changes**:
  - reps/weight/duration/distance에 대한 quick adjust action을 ViewModel에 추가한다.
  - draft preview에서 exercise input type에 맞는 editing controls를 노출한다.
  - draft 편집 시 `isDraftSaved`를 해제하고 confirmation state를 최신 draft 기준으로 다시 맞춘다.
- **Verification**:
  - strength/cardio draft 각각에 대해 adjustment 결과가 올바른지 unit test로 고정한다.

### Step 3: Update localization and TODO bookkeeping

- **Files**: `Localizable.xcstrings`, `todos/023-in-progress-p2-vision-phase4-remaining.md`, 새/기존 voice TODO
- **Changes**:
  - 새 confirmation/editing 문구를 en/ko/ja로 추가한다.
  - 이번 배치가 닫는 하위 TODO를 `done`으로 정리하고, `023`에는 남은 범위만 남긴다.
- **Verification**:
  - `xcstrings`에 필요한 키가 모두 존재하는지 확인한다.
  - TODO 파일명/frontmatter/status/updated 날짜가 규칙과 일치하는지 확인한다.

## Edge Cases

| Case | Handling |
|------|----------|
| locale에 맞는 TTS voice가 없음 | explicit voice 없이 utterance를 speak하거나 no-op fallback |
| 사용자가 listening 중 review/save를 시도 | 텍스트 상태는 갱신하되 speech feedback는 생략 |
| exercise type에 없는 metric 편집을 요청 | control을 숨기고 ViewModel action도 no-op 처리 |
| 저장 후 draft를 다시 수정 | `isDraftSaved`를 false로 되돌리고 다시 저장 가능 상태로 전환 |

## Testing Strategy

- Unit tests: confirmation summary, speech feedback trigger, metric adjustment, save gating
- Integration tests: 없음. SwiftData insert 책임은 기존 `VisionVoiceWorkoutEntryCard` 경로 유지
- Manual verification: visionOS simulator에서 review/save UX copy와 draft quick adjust 흐름 확인, TTS는 simulator 제한 시 텍스트 fallback만 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `Localizable.xcstrings` 수동 수정 실수 | medium | medium | 기존 key 형식을 따라 최소 키만 추가하고 빌드로 검증 |
| simulator에서 TTS runtime 동작이 불안정 | medium | low | speaker protocol로 분리하고 텍스트 confirmation을 기본 UX로 유지 |
| quick adjust 단위(kg/lb, km/mi) 해석이 저장 규칙과 어긋남 | medium | medium | existing normalization 경로를 재사용하고 테스트로 고정 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 voice foundation/persistence 구조가 이미 있어 변경 범위는 명확하다. 다만 `xcstrings` 수동 수정과 visionOS speech runtime 차이 때문에 build/test로 빠르게 검증하는 접근이 필요하다.
