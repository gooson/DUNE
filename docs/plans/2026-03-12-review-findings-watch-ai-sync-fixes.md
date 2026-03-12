---
topic: review-findings-watch-ai-sync-fixes
date: 2026-03-12
status: approved
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-12-watch-reinstall-library-rehydrate.md
  - docs/solutions/general/2026-03-12-ai-workout-builder-natural-language-reliability.md
  - docs/solutions/architecture/2026-03-12-set-rpe-integration.md
  - docs/solutions/general/2026-03-02-title-policy-watch-localization-fixes.md
related_brainstorms:
  - docs/brainstorms/2026-03-07-preferred-exercise-ordering.md
---

# Implementation Plan: Review Findings Watch/AI/Sync Fixes

## Context

오늘 리뷰에서 3건의 P2가 남았다.

1. watch exercise library re-sync가 전체 `ExerciseRecord`를 매번 다시 읽는다.
2. AI workout prompt parser가 한국어 `등`을 raw substring으로 해석해 오분류할 수 있다.
3. watch RPE picker의 일부 런타임 문자열이 watch xcstrings에서 비어 있다.

이번 작업은 위 3건을 수정하고, 관련 회귀 테스트와 빌드 검증까지 포함한다.

## Requirements

### Functional

- watch exercise library sync가 반복 refresh마다 full-history fetch를 강제하지 않아야 한다.
- settings/defaults 변경 후 watch payload는 여전히 최신 preferred/default 값을 반영해야 한다.
- AI prompt parser가 `등`을 "etc." 용법과 등/광배 근육 의도를 구분해야 한다.
- watch RPE picker의 live subtitle/accessibility copy가 ko/ja에서 번역 가능해야 한다.

### Non-functional

- 기존 watch reinstall rehydrate 동작을 깨지 않아야 한다.
- 기존 broad-prompt reliability 회귀를 만들지 않아야 한다.
- localization 규칙과 Swift Testing 패턴을 따라야 한다.
- detached `HEAD` 상태에서 직접 커밋하지 않고 `codex/` 작업 브랜치에서 진행해야 한다.

## Approach

watch sync는 "fresh rebuild"와 "cached transfer"를 분리한다. 앱 시작 시 1회 fresh payload를 만들고, 이후 watch request/activation은 캐시를 재사용한다. settings에서 default/preferred만 바뀌는 경로는 `ModelContext` 기반 lightweight default-only refresh로 payload를 갱신한다.

AI parser는 keyword 매칭 헬퍼를 도입해 raw substring 대신 boundary-aware match를 사용한다. 특히 한국어 `등`은 단독 토큰이어도 list filler(`A, B 등 ...`)와 back-muscle intent를 구분하는 규칙을 둔다.

watch localization은 code path는 유지하고 `DUNEWatch/Resources/Localizable.xcstrings`의 실제 런타임 키(`%@ reps left`, `Clear RPE`)를 채운다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| watch sync에 TTL 캐시만 추가 | 구현이 가장 단순 | stale payload와 trigger semantics가 모호 | 기각 |
| exercise history를 최근 N건으로 잘라 fetch | read cost 감소 | usageCount/popular ordering 정확도 하락 | 기각 |
| AI parser에서 `등` keyword 제거 | 빠른 수정 | `등 운동` 한국어 정상 입력 회귀 | 기각 |
| watch RPE subtitle를 help-sheet short label로 교체 | xcstrings 변경량 감소 | UX copy가 바뀌고 기존 iOS/watch parity가 흔들림 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | modify | cached transfer와 default-only refresh 경로 분리 |
| `DUNE/Presentation/Settings/Components/ExerciseDefaultEditView.swift` | modify | settings save/clear에서 lightweight sync 사용 |
| `DUNE/Presentation/Settings/Components/PreferredExercisesListView.swift` | modify | preferred toggle에서 lightweight sync 사용 |
| `DUNE/Data/Services/AIWorkoutTemplateGenerator.swift` | modify | boundary-aware keyword matching 도입 |
| `DUNETests/AIWorkoutTemplateGeneratorTests.swift` | modify | `등` filler/back-intent 회귀 테스트 추가 |
| `DUNEWatch/Resources/Localizable.xcstrings` | modify | `%@ reps left`, `Clear RPE` watch 번역 보강 |
| `DUNETests/WatchExerciseLibraryPayloadBuilderTests.swift` | modify | default-only refresh/helper 회귀 테스트 추가 또는 manager helper 테스트 보강 |

## Implementation Steps

### Step 1: watch sync refresh 경로 분리

- **Files**: `WatchSessionManager.swift`, `ExerciseDefaultEditView.swift`, `PreferredExercisesListView.swift`
- **Changes**:
  - cached exercise payload reuse 정책 추가
  - default/preferred 변경용 lightweight sync API 추가
  - activation/watch-request는 캐시 우선, cold start만 fresh rebuild
- **Verification**:
  - settings call site가 full-history path를 직접 호출하지 않는지 확인
  - watch sync helper/unit test 추가

### Step 2: AI parser keyword matching 보정

- **Files**: `AIWorkoutTemplateGenerator.swift`, `AIWorkoutTemplateGeneratorTests.swift`
- **Changes**:
  - keyword matching helper 추가
  - `등`의 filler 용법 회피
  - 기존 `등 운동` 같은 명시 입력은 유지
- **Verification**:
  - 새 테스트 2개: filler case, explicit back case

### Step 3: watch xcstrings 번역 보강

- **Files**: `DUNEWatch/Resources/Localizable.xcstrings`
- **Changes**:
  - `%@ reps left` ko/ja value 추가
  - `Clear RPE` ko/ja value 추가
- **Verification**:
  - 키가 비어 있지 않은지 확인
  - localization review checklist 재대조

### Step 4: test/build/re-review

- **Files**: tests + build artifacts
- **Changes**:
  - 관련 unit test 실행
  - `scripts/build-ios.sh` 실행
  - diff 기준 재리뷰로 finding 재확인
- **Verification**:
  - build success
  - targeted tests pass
  - 기존 3건이 resolved 또는 stale after fix로 정리

## Edge Cases

| Case | Handling |
|------|----------|
| watch app activation 직후 캐시가 비어 있음 | registered container로 1회 fresh rebuild |
| settings 변경 직전 cached exercise payload가 비어 있음 | lightweight path에서 fallback/full rebuild로 복구 |
| query가 정확히 `등 운동` 또는 `20분 등 운동` | back-muscle intent로 계속 인식 |
| query에 `덤벨, 밴드 등 상체 운동`처럼 filler `등`이 포함 | back-muscle intent로 취급하지 않음 |
| `%@ reps left` format key locale ordering 차이 | xcstrings format string으로 처리 |

## Testing Strategy

- Unit tests:
  - `DUNETests/AIWorkoutTemplateGeneratorTests`
  - watch sync helper regression tests (`DUNETests/...` existing file 보강)
- Integration tests:
  - 없음. 이번 범위는 helper/service 단위로 제한
- Manual verification:
  - `scripts/build-ios.sh`
  - diff/localization key inspection

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| cached watch payload가 stale 될 수 있음 | medium | medium | cold start/fallback/full rebuild 경로 유지, settings path는 즉시 cache 갱신 |
| keyword matcher가 기존 broad prompt 성능을 떨어뜨릴 수 있음 | medium | medium | explicit regression tests 추가 |
| xcstrings 수동 편집 포맷 오류 | low | medium | 변경 키 최소화, build로 검증 |
| detached HEAD에서 커밋 손실 | low | high | Work 시작 전에 `codex/` 브랜치 생성 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 세 문제 모두 수정 범위는 좁지만, watch sync는 cache/fresh semantics를 잘못 나누면 rehydrate 회귀가 날 수 있어 테스트와 재리뷰가 필수다.
