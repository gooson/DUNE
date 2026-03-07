---
topic: exercise-variant-canonicalization
date: 2026-03-07
status: approved
confidence: high
related_solutions:
  - docs/solutions/general/2026-02-26-quickstart-ia-usage-tracking-consistency.md
related_brainstorms:
  - docs/brainstorms/2026-02-26-exercise-type-reorg-quickstart.md
  - docs/brainstorms/2026-02-28-improve-cardio-logging.md
---

# Implementation Plan: Exercise Variant Canonicalization

## Context

운동 라이브러리에 같은 본운동의 변형(`intervals`, `endurance`, `recovery`, 기존 `tempo`/`paused`)이 별도 엔트리로 함께 노출되어 운동 선택 부담이 커진다. 하지만 기존 기록, 템플릿, WatchConnectivity payload는 variant ID를 이미 사용할 수 있으므로 원본 ID 삭제는 하위 호환 리스크가 높다.

## Requirements

### Functional

- 운동 선택/검색/Watch 전송에 사용되는 노출 목록은 같은 본운동을 canonical 기준 1개로 정리한다.
- `running`, `running-intervals`, `running-endurance`, `running-recovery` 같은 cardio 변형을 하나로 묶는다.
- `yoga` 와 `yoga-recovery-flow` 같은 recovery-flow 계열도 하나로 묶는다.
- 기존 variant ID는 `exercise(byID:)` lookup 으로 계속 찾을 수 있어야 한다.
- 검색에서 variant 키워드(`interval`, `recovery`)로 검색해도 canonical 대표 운동이 노출되어야 한다.

### Non-functional

- 기존 Quick Start / Watch canonical 규칙과 충돌하지 않도록 단일 canonical 규칙을 확장한다.
- JSON 원본을 삭제하지 않고 서비스 레이어에서 정리해 기록/템플릿 호환성을 유지한다.
- 회귀 방지를 위한 단위 테스트를 추가한다.

## Approach

`ExerciseLibraryService`가 원본 라이브러리는 그대로 보유하되, 외부에 노출하는 `allExercises/search/filter` 결과를 canonical 대표 운동 기준으로 정리한다. 대표 운동 선택은 가능한 경우 canonical ID와 일치하는 기본 운동을 우선하고, 없으면 이름/ID가 가장 안정적인 엔트리를 사용한다. 동시에 Quick Start와 Watch에서 사용하는 canonical 규칙에 `interval`, `recovery`, `recovery-flow`를 추가해 중복 제거 기준을 일치시킨다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `exercises.json`에서 variant 항목 삭제 | 가장 단순한 노출 결과 | 기존 기록/템플릿/lookup 깨질 가능성 큼 | 기각 |
| UI별로 개별 dedup 처리 | 영향 범위를 국소화 가능 | iPhone/Watch/설정/추천 간 규칙 drift 발생 | 기각 |
| 서비스 레이어에서 canonical 노출 + 원본 lookup 유지 | 하위 호환 + 일관된 노출 + Watch sync에도 반영 | 대표 선택 규칙 설계 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/UseCases/QuickStartPopularityService.swift` | modify | canonical ID/name 규칙에 interval/recovery 계열 추가 |
| `DUNEWatch/Managers/RecentExerciseTracker.swift` | modify | Watch canonical ID 규칙을 iPhone과 동일 범위로 확장 |
| `DUNE/Data/ExerciseLibraryService.swift` | modify | canonical 대표 목록/검색 dedup 및 exact lookup 유지 |
| `DUNETests/QuickStartPopularityServiceTests.swift` | modify | 새 canonical 규칙 테스트 추가 |
| `DUNETests/ExerciseDefinitionTests.swift` | modify | library 노출/검색이 canonical 기준으로 정리되는지 검증 |
| `DUNEWatchTests/RecentExerciseTrackerTests.swift` | modify | Watch canonical rule 확장 검증 |

## Implementation Steps

### Step 1: canonical 규칙 확장

- **Files**: `DUNE/Domain/UseCases/QuickStartPopularityService.swift`, `DUNEWatch/Managers/RecentExerciseTracker.swift`
- **Changes**: interval/recovery/recovery-flow suffix, 관련 localized name suffix를 canonical 규칙에 추가한다.
- **Verification**: running/cycling/yoga recovery 변형이 각각 기본 운동 canonical key로 정규화된다.

### Step 2: ExerciseLibraryService 노출 목록 정리

- **Files**: `DUNE/Data/ExerciseLibraryService.swift`
- **Changes**: raw exercises와 exact lookup map은 유지하고, `allExercises/search/exercises(for*)`는 canonical 대표 exercise만 반환하도록 정리한다. 검색은 raw 전체를 검색한 뒤 canonical 대표로 축약한다.
- **Verification**: `allExercises()`에 `running-intervals`, `running-endurance`, `running-recovery`가 동시에 남지 않고 `running` 1개만 노출된다. `exercise(byID: "running-recovery")`는 계속 동작한다.

### Step 3: 테스트 보강

- **Files**: `DUNETests/QuickStartPopularityServiceTests.swift`, `DUNETests/ExerciseDefinitionTests.swift`, `DUNEWatchTests/RecentExerciseTrackerTests.swift`
- **Changes**: canonicalization, library dedup, variant 검색 fallback, watch parity 테스트를 추가한다.
- **Verification**: 대상 테스트 스위트가 모두 통과한다.

## Edge Cases

| Case | Handling |
|------|----------|
| canonical base ID가 실제로 존재하는 경우 | base ID exercise를 대표 엔트리로 우선 선택 |
| canonical base ID가 없는 변형군 | canonical key 동일 그룹 중 localizedName/ID 기준으로 안정적인 엔트리 선택 |
| 기존 템플릿/기록이 variant ID를 저장한 경우 | `exercise(byID:)`는 raw map 유지로 그대로 해석 |
| `interval`로 검색했을 때 base 이름이 query를 직접 포함하지 않는 경우 | raw match 결과를 canonical 대표 exercise로 축약해 base 엔트리 반환 |
| recovery flow가 별도 프로그램처럼 느껴질 수 있는 경우 | 이번 요청 범위에서는 “같은 종류 운동 하나로 정리” 우선, 원본 ID/alias는 유지 |

## Testing Strategy

- Unit tests: canonical suffix 확장, ExerciseLibraryService dedup/lookup/search behavior, Watch canonical parity
- Integration tests: 없음 (서비스/정규화 레이어 중심 변경)
- Manual verification: iPhone Exercise picker Quick Start/Full list, watch Quick Start all exercises, settings defaults search에서 cardio/flexibility 중복이 사라졌는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 과도한 canonicalization으로 다른 운동이 잘못 묶임 | low | medium | suffix 기반으로만 확장하고 base ID 우선 대표 선택 |
| 노출 목록 축약이 추천/설정 화면 기대와 충돌 | medium | low | exact lookup은 유지하고 테스트로 filter/search 동작 검증 |
| iPhone/Watch canonical 규칙 불일치 | medium | medium | 두 canonical 구현에 같은 suffix 세트를 반영하고 parity 테스트 추가 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 코드베이스에 canonical dedup 패턴이 이미 존재하고, 이번 변경은 suffix 규칙 확장과 서비스 레이어 일관화에 집중된 범위다.
