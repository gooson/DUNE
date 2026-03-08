---
tags: [pr-review, github, audit, review-followup, muscle-map, recommendation, wellness, watch-ui-test]
date: 2026-03-09
category: plan
status: reviewed
---

# PR 리뷰 코멘트 감사 및 후속 수정 계획

## Context

2026-03-09 기준 `gh pr list --state open` 결과는 0건이다. 그래서 현재 작업 집합은 2026-03-08에 업데이트된 최근 merged PR 30건으로 좁혀 조사했다. 그 결과 6개 PR에서 inline review comment 10건이 확인됐고, 이 중 9건은 현재 `main`에도 그대로 남아 있어 후속 수정이 필요하다.

## Requirements

### Functional

- 최근 merged PR review comment 10건을 PR 번호/우선순위/현재 상태 기준으로 정리한다.
- 현재 `main`에서 이미 해소된 comment와 아직 남아 있는 comment를 구분한다.
- 남아 있는 comment를 코드와 테스트에 반영한다.
- 조사와 수정 진행 상황을 `todos/` 파일로 추적한다.

### Non-functional

- 수정 범위는 review comment가 지적한 경로로 제한한다.
- 기존 패턴과 테스트 자산을 재사용한다.
- build와 관련 테스트로 회귀를 검증한다.

## Approach

최근 merged PR의 GitHub review thread를 직접 수집해 현재 `main`과 대조하고, `Open`/`Stale after fix`로 분류한 뒤 `Open` 항목만 한 배치로 수정한다. 수정은 성격별로 묶는다.

1. watch/iOS UI 테스트의 결정론 보강
2. recommendation resolver의 sequence 보존과 fallback 보강
3. Activity/Wellness의 파생 상태 재계산 트리거 보강
4. MuscleMap3DScene의 preload 시점 cache 오염 방지

### Comment Inventory

| PR | Priority | File | Summary | Current Status |
|----|----------|------|---------|----------------|
| #423 | P1 | `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift` | seeded watch smoke에서 `Recent` section 강제 금지 | Open |
| #420 | P1 | `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift` | muscle cache를 geometry 준비 전에 기록하지 않기 | Open |
| #420 | P2 | `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift` | shell opacity cache를 shell entity 준비 전에 기록하지 않기 | Open |
| #402 | P1 | `DUNE/Presentation/Exercise/TemplateExerciseResolver.swift` | unresolved step을 drop하지 말고 sequence 보존 | Open |
| #402 | P2 | `DUNE/Presentation/Exercise/TemplateExerciseResolver.swift` | generic strength recommendation에 activity fallback 허용 | Open |
| #400 | P1 | `DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift` | 3D navigation tap을 결정론적 selector 기반으로 전환 | Open |
| #401 | P1 | `DUNE/Presentation/Wellness/WellnessView.swift` | load 완료 후 sleep prediction 재계산 보장 | Open |
| #401 | P2 | `DUNE/Presentation/Activity/ActivityView.swift` | active injury 변경 시 항상 injury risk 재계산 | Open |
| #401 | P2 | `DUNE/Presentation/Activity/ActivityView.swift` | record 변경 시 weekly report 재생성 | Open |
| #396 | P1 | `DUNE/project.yml`, `DUNE.xcodeproj` | `muscle_body.usdz`를 DUNEVision resources에 포함 | Stale after fix |

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| open PR만 조사 | 가장 엄격하게 "현재 PR"에 맞음 | open PR이 0건이라 실제 남은 review debt를 놓침 | 기각 |
| 최근 merged PR 전수 조사 | 지금 남아 있는 review debt를 바로 정리 가능 | 과거 전체 히스토리는 아님 | 채택 |
| comment별로 별도 PR 생성 | 원인 추적이 쉬움 | 현재는 open PR이 없고 후속 수정 배치가 더 효율적 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-09-pr-review-comment-audit.md` | add | 이번 감사/수정 계획 문서 |
| `todos/107-in-progress-p2-pr-review-comment-audit.md` | add | 감사 및 수정 진행 TODO |
| `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift` | modify | seeded home smoke assertion 완화 |
| `DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift` | modify | 3D 진입 selector를 결정론적으로 교체 |
| `DUNE/Presentation/Exercise/TemplateExerciseResolver.swift` | modify | recommendation sequence 보존 + strength fallback 보강 |
| `DUNE/Presentation/Activity/ActivityView.swift` | modify | records/injury 변경 fingerprint 보강 + weekly report/injury risk 재계산 |
| `DUNE/Presentation/Wellness/WellnessView.swift` | modify | stale sleep prediction trigger 제거 |
| `DUNE/Presentation/Wellness/WellnessViewModel.swift` | modify | load 완료 시 sleep prediction 재계산 |
| `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift` | modify | preload 시 cache 오염 방지 |
| `DUNETests/TemplateExerciseResolverTests.swift` | modify | unresolved sequence/strength fallback 회귀 테스트 |
| `DUNETests/WellnessViewModelTests.swift` | modify | refresh 후 sleep prediction 회귀 테스트 |

## Implementation Steps

### Step 1: 감사 결과 문서화와 TODO 생성

- **Files**: `docs/plans/2026-03-09-pr-review-comment-audit.md`, `todos/107-in-progress-p2-pr-review-comment-audit.md`
- **Changes**:
  - comment inventory와 triage 결과를 문서화한다.
  - TODO에 PR별 진행 상태를 체크리스트로 기록한다.
- **Verification**:
  - `docs/plans/`와 `todos/`에 새 파일이 존재한다.

### Step 2: UI 테스트 결정론 보강

- **Files**: `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift`, `DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift`
- **Changes**:
  - watch smoke에서 optional `Recent` section을 필수 surface로 취급하지 않는다.
  - muscle map 3D navigation 테스트는 좌표 탭 대신 muscle AXID selector를 사용한다.
- **Verification**:
  - watch smoke와 muscle map UI test가 seeded/no-recent 상태에서도 안정적으로 통과한다.

### Step 3: Recommendation/derived-state follow-up 수정

- **Files**: `DUNE/Presentation/Exercise/TemplateExerciseResolver.swift`, `DUNE/Presentation/Activity/ActivityView.swift`, `DUNE/Presentation/Wellness/WellnessView.swift`, `DUNE/Presentation/Wellness/WellnessViewModel.swift`, `DUNETests/TemplateExerciseResolverTests.swift`, `DUNETests/WellnessViewModelTests.swift`
- **Changes**:
  - unresolved recommendation step이 있으면 truncate 대신 실패로 처리한다.
  - strength recommendation도 activity-type fallback을 사용할 수 있게 한다.
  - `recordsUpdateKey`와 injury observation을 fingerprint 기반으로 바꿔 edit-in-place도 감지한다.
  - record change 경로에서 weekly report 재생성을 포함한다.
  - sleep prediction은 load 완료 시점에 recompute하고, stale trigger를 제거한다.
- **Verification**:
  - resolver unit test와 wellness unit test가 회귀를 고정한다.

### Step 4: 3D scene preload cache 방어

- **Files**: `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift`
- **Changes**:
  - geometry/shell entity 준비 전에는 cache snapshot을 기록하지 않도록 guard를 추가한다.
- **Verification**:
  - build가 통과하고, first-load visual regression을 유발할 조기 cache path가 제거된다.

## Edge Cases

| Case | Handling |
|------|----------|
| open PR이 0건 | 최근 merged PR 30건을 current audit scope로 사용 |
| review comment가 이미 후속 PR에서 해결됨 | `Stale after fix`로 분류하고 코드 수정에서 제외 |
| recommendation label 하나만 unresolved | 조용히 drop하지 않고 전체 추천 시작을 중단 |
| record/injury edit가 count를 바꾸지 않음 | hash/fingerprint 기반 change key로 감지 |
| 3D scene refresh가 prepare 전에 먼저 호출됨 | cache를 건드리지 않고 준비 후 첫 refresh에서 정상 적용 |

## Testing Strategy

- Unit tests: `DUNETests/TemplateExerciseResolverTests.swift`, `DUNETests/WellnessViewModelTests.swift`
- Integration tests: `scripts/build-ios.sh`
- Manual verification:
  - review comment inventory와 current status 대조
  - `gh pr list --state open`가 0건임을 재확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `recordsUpdateKey` 확장으로 불필요한 refresh 증가 | Medium | Medium | 최소 fingerprint만 포함하고 기존 debounced refresh 경로 유지 |
| sleep prediction recompute 위치 이동으로 중복 계산 | Low | Low | View 레벨 stale trigger 제거로 단일 load 완료 경로로 수렴 |
| 3D scene cache guard가 기존 update 타이밍을 막음 | Low | Medium | entity 존재 확인 후에만 cache를 기록하도록 제한 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: review comment가 지적한 재현 경로는 명확하지만, Activity/RealityKit 쪽은 view lifecycle과 refresh frequency까지 같이 건드리므로 build와 테스트 확인이 필요하다.
