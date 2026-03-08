---
topic: vision-pro-voice-entry-foundation
date: 2026-03-08
status: approved
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-07-vision-pro-exercise-form-guide.md
  - docs/solutions/architecture/2026-03-07-vision-pro-multi-window-dashboard.md
related_brainstorms:
  - docs/brainstorms/2026-03-05-vision-pro-features.md
---

# Implementation Plan: Vision Pro Voice-First Workout Entry Foundation

## Context

`todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md`의 남은 범위 중 `G1 SharePlay`와 `F3 Voice-First Workout Entry`는 아직 코드 스캐폴드가 전혀 없다. 현재 `DUNEVision`은 `Train` 탭에서 spatial guide와 fatigue surface를 제공하지만, 운동을 음성으로 빠르게 입력할 수 있는 workflow는 없다.

full SharePlay는 GroupActivities, SharedWorldAnchors, 멀티유저 검증까지 한 번에 필요해 현재 배치 범위를 초과한다. 반면 `F3`는 existing `ExerciseLibraryService`, `QuickStartCanonicalService`, `ExerciseInputType`, `CardioSecondaryUnit`을 재사용하면 **speech capture + command parser + draft preview**까지는 shippable foundation으로 구현 가능하다.

이번 배치는 workout history 저장까지 닫는 것이 아니라, Vision Pro에서 음성 문장을 구조화된 운동 draft로 바꾸는 foundation을 먼저 ship한다. 실제 SwiftData persistence와 multi-device sync는 후속 phase로 남긴다.

## Requirements

### Functional

- visionOS `Train` 탭에서 음성 workout draft surface를 노출한다.
- 사용자는 마이크 버튼으로 speech capture를 시작/중지할 수 있어야 한다.
- 사용자는 transcript를 직접 수정하고 다시 parse할 수 있어야 한다.
- parser는 최소한 strength(`벤치프레스 80kg 8회`)와 cardio(`러닝 30분 5km`) 패턴을 지원해야 한다.
- parser는 `ExerciseLibraryService`를 이용해 exercise를 resolve하고, 입력 타입에 맞는 draft metric을 생성해야 한다.
- parse 실패 시 원인을 사용자에게 알려야 한다.
- draft UI는 "현재는 preview foundation이며 저장은 후속 scope"라는 사실을 명확히 보여야 한다.
- umbrella TODO `020`에 F3 foundation 진행 사실을 반영한다.

### Non-functional

- speech framework 의존 코드는 protocol 뒤로 숨겨 view model/unit test에서 mock 가능해야 한다.
- parsing 로직은 pure Foundation 중심으로 분리해 `DUNETests`에서 회귀 테스트로 고정한다.
- 새 사용자 문자열은 `Shared/Resources/Localizable.xcstrings`에 en/ko/ja 3개 언어로 등록한다.
- DUNEVision target에는 speech/microphone privacy description과 필요한 framework wiring을 추가한다.
- workout persistence stack 전체를 DUNEVision에 끌어오지 않는다.

## Approach

shared `DUNE/Presentation/Vision/` 레이어에 두 개의 핵심 축을 추가한다.

1. `VisionVoiceWorkoutCommandParser`
   - transcript를 정규화하고 metric token(weight/reps/duration/distance)을 추출한다.
   - metric phrase를 제거한 나머지 텍스트로 exercise query를 만들고, `ExerciseLibraryService` 기반 score로 best match를 선택한다.
   - 결과를 `VisionVoiceWorkoutDraft`로 반환한다.

2. `VisionVoiceWorkoutEntryViewModel`
   - speech authorization/start/stop lifecycle과 transcript editing/parse action을 관리한다.
   - speech engine은 protocol 기반 service로 분리하고, 실제 구현은 `Speech` + `AVAudioEngine`을 사용한다.
   - UI는 DUNEVision 전용 card에서 이 view model만 소비한다.

이 구조는 기존 visionOS feature pattern과 맞는다. 실제 scene wiring은 얇게 유지하고, feature state는 shared Presentation layer에서 테스트 가능하게 만든다. 또한 persistence 미구현 사실을 UI에 명시함으로써 "완전한 운동 저장"과 "voice draft foundation"을 구분한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `G1 SharePlay`를 먼저 구현 | social novelty가 높음 | GroupActivities + SharedWorldAnchors + multi-user 검증이 한 번에 필요 | 기각 |
| voice entry를 SwiftData 저장까지 포함해 끝냄 | TODO F3를 더 크게 닫을 수 있음 | DUNEVision target에 exercise persistence stack과 save flow를 넓게 이식해야 함 | 기각 |
| parser 없이 transcript만 보여주는 speech demo | 구현이 가장 빠름 | 실제 workout draft 가치가 거의 없고 TODO 진척으로 보기 어려움 | 기각 |
| speech + parser + draft preview foundation | 기존 exercise metadata 재사용, 테스트 가능, 후속 save path와 자연스럽게 연결 | 이번 배치에서 직접 저장은 못함 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-08-vision-pro-voice-entry-foundation.md` | add | 이번 배치 계획서 |
| `DUNE/Presentation/Vision/VisionVoiceWorkoutCommandParser.swift` | add | transcript → structured draft parser |
| `DUNE/Presentation/Vision/VisionVoiceWorkoutEntryViewModel.swift` | add | speech lifecycle + parse state 관리 |
| `DUNEVision/Presentation/Activity/VisionVoiceWorkoutEntryCard.swift` | add | Vision Pro 음성 draft UI |
| `DUNEVision/Presentation/Activity/VisionTrainView.swift` | modify | Train 탭에 voice draft card 삽입 |
| `DUNE/project.yml` | modify | DUNEVision speech privacy key / framework wiring |
| `Shared/Resources/Localizable.xcstrings` | modify | voice draft copy 추가 |
| `DUNETests/VisionVoiceWorkoutCommandParserTests.swift` | add | parser strength/cardio/실패 케이스 고정 |
| `DUNETests/VisionVoiceWorkoutEntryViewModelTests.swift` | add | authorization/start/parse state 검증 |
| `todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md` | modify | F3 foundation 진행 메모 반영 |

## Implementation Steps

### Step 1: Add a reusable voice workout parser

- **Files**: `VisionVoiceWorkoutCommandParser.swift`, `VisionVoiceWorkoutCommandParserTests.swift`
- **Changes**:
  - strength/cardio utterance에서 metric token을 추출하는 pure parser를 추가한다.
  - exercise query normalization + library match scoring 로직을 추가한다.
  - parse 성공/실패 결과를 draft model로 구조화한다.
- **Verification**:
  - `벤치프레스 80kg 8회`, `Bench Press 176 lb 8 reps`, `러닝 30분 5km` 파싱 테스트
  - exercise 미탐색/metric 부족 실패 케이스 테스트

### Step 2: Add speech-driven entry state management

- **Files**: `VisionVoiceWorkoutEntryViewModel.swift`, `VisionVoiceWorkoutEntryViewModelTests.swift`
- **Changes**:
  - speech authorization, listening start/stop, transcript update, parse action을 관리하는 view model을 추가한다.
  - real speech service는 protocol 뒤로 감추고 mock으로 테스트 가능하게 만든다.
  - parse 결과와 에러/상태 메시지를 view-friendly state로 노출한다.
- **Verification**:
  - authorization denied/unavailable 분기 테스트
  - transcript 수신 후 parse success/failure state 테스트
  - stop listening이 상태를 정리하는지 테스트

### Step 3: Surface the draft UI in visionOS Train tab

- **Files**: `VisionVoiceWorkoutEntryCard.swift`, `VisionTrainView.swift`, `Shared/Resources/Localizable.xcstrings`, `DUNE/project.yml`
- **Changes**:
  - voice entry card UI를 추가하고 Train tab ready state 안에 배치한다.
  - speech/mic usage description과 framework wiring을 추가한다.
  - foundation preview 한계를 설명하는 copy를 추가한다.
- **Verification**:
  - visionOS build 통과
  - localization key 누락 없음
  - UI에서 transcript edit + parse result가 표시됨

### Step 4: Record TODO progress and keep roadmap honest

- **Files**: `todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md`
- **Changes**:
  - F3 전체 완료가 아니라 foundation이 추가됐음을 명시한다.
  - persistence/save path는 후속 phase로 남겨 scope를 과장하지 않는다.
- **Verification**:
  - TODO 파일명/status 규칙 유지
  - umbrella TODO 메모가 실제 구현 범위와 일치

## Edge Cases

| Case | Handling |
|------|----------|
| transcript에 숫자는 있지만 exercise phrase가 없음 | parse failure로 반환하고 수정 안내 메시지 노출 |
| exercise는 찾았지만 해당 input type 필수 metric이 부족함 | partial success 대신 명시적 failure로 처리 |
| `lb` 입력이 들어옴 | draft에 원 단위를 유지하되 parser는 내부 비교 가능한 numeric로 정규화 |
| Korean/English alias가 섞여 있음 | normalized exercise query + library alias/name/localizedName score로 best match 선택 |
| speech authorization가 거부됨 | transcript 수동 입력만 허용하고 listening 버튼은 에러 상태로 전환 |
| speech session이 중간 오류로 종료됨 | listening state를 해제하고 마지막 transcript는 유지 |

## Testing Strategy

- Unit tests: parser token extraction, exercise resolution, validation failures
- ViewModel tests: authorization/listening/parse transitions with mock speech service
- Build verification: `scripts/build-ios.sh`
- Targeted tests: `scripts/test-unit.sh` 또는 `swift test`/`xcodebuild test`로 `VisionVoiceWorkout*Tests`
- Manual verification: visionOS simulator에서 Train 탭 진입 → listening 시작/중지 → transcript 수정 → draft preview 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| speech API runtime behavior가 simulator와 실기기에서 다름 | medium | medium | speech service를 protocol로 분리하고 UI/manual 입력 fallback 유지 |
| parser가 exercise library ranking 때문에 잘못된 exercise를 선택 | medium | medium | exact/contains/token score 기반 선택 + 대표 케이스 테스트 추가 |
| foundation preview를 사용자가 저장 기능으로 오해 | medium | low | UI copy에 preview/follow-up scope를 명확히 표기 |
| DUNEVision target privacy/framework wiring 누락으로 build/runtime failure | low | high | `project.yml` + build script로 platform build 검증 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: shared exercise metadata와 visionOS feature wiring 패턴은 이미 존재해 foundation 구현은 명확하다. 다만 speech runtime은 simulator 제약이 있어 manual verification과 fallback copy를 함께 둬야 한다.
