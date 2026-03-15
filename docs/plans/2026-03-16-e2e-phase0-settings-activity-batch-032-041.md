---
topic: e2e phase0 settings activity batch 032 041
date: 2026-03-16
status: draft
confidence: medium
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase0-page-backlog-split.md
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
  - docs/solutions/testing/2026-03-08-e2e-phase3-activity-exercise-regression-hardening.md
  - docs/solutions/testing/2026-03-03-ipad-activity-tab-ui-test-navigation-stability.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: E2E Phase 0 Settings and Activity Batch 032-041

## Context

`todos/032`~`041`는 DUNE Today/Settings와 Activity 탭의 남은 must-have phase 0 E2E surface다.
기존 프로젝트에는 launch scenario, seeded fixture, Activity/Settings regression file이 이미 있으므로,
이번 배치는 새 테스트 타깃을 만들기보다 기존 regression suite를 확장하고 필요한 화면 anchor/selector만 보강하는 방식이 가장 안전하다.

## Requirements

### Functional

- `032`~`041` 각 surface에 대해 entry route, selector inventory, 주요 assertion scope, lane 근거를 실제 코드와 TODO 문서에 반영한다.
- Settings 하위 surface (`ExerciseDefaultsListView`, `ExerciseDefaultEditView`, `PreferredExercisesListView`)를 실제 navigation + edit/toggle 흐름으로 검증한다.
- Activity 하위 surface (`ActivityView`, `TrainingReadinessDetailView`, `WeeklyStatsDetailView`, `TrainingVolumeDetailView`, `ExerciseTypeDetailView`, `PersonalRecordsDetailView`, `ConsistencyDetailView`)를 seeded flow로 검증한다.
- 완료된 TODO는 `done`으로 전환하고 open/completed backlog index를 동기화한다.

### Non-functional

- 기존 `DUNEUITests` 인프라와 seeded scenario를 재사용한다.
- 테스트는 locale-safe selector와 iPad-safe navigation helper를 우선 사용한다.
- Xcode project 구조 변경은 피하고 기존 test file 확장으로 마무리한다.

## Approach

기존 `TodaySettingsRegressionTests`, `ActivityExerciseRegressionTests`, `ChartInteractionRegressionUITests`를 중심으로 테스트를 추가하고,
테스트가 안정적으로 surface를 집을 수 있도록 대상 화면에 screen/section/control 수준의 AXID를 보강한다.
Settings surface는 별도 seeded record가 없으므로 테스트 내부에서 저장/토글을 수행해 상태 전이를 직접 검증한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 새 regression test file 여러 개 생성 | surface 분리도가 높음 | `pbxproj`/scheme 반영 비용이 커지고 detached HEAD 배치에서 리스크가 증가 | Rejected |
| TODO 문서만 `done` 처리 | 빠름 | 실제 selector/test contract가 없어 phase 0 목적을 충족하지 못함 | Rejected |
| 기존 regression file 확장 + AXID 보강 | project 변경 최소화, 기존 helper 재사용 가능 | 테스트 파일 길이가 길어짐 | Accepted |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Settings/Components/ExerciseDefaultsListView.swift` | modify | screen/row level AXID 추가 |
| `DUNE/Presentation/Settings/Components/ExerciseDefaultEditView.swift` | modify | form field/toggle/action AXID 추가 |
| `DUNE/Presentation/Settings/Components/PreferredExercisesListView.swift` | modify | screen/section AXID 추가 |
| `DUNE/Presentation/Activity/TrainingReadiness/TrainingReadinessDetailView.swift` | modify | picker/sub-score anchor AXID 추가 |
| `DUNE/Presentation/Activity/WeeklyStats/WeeklyStatsDetailView.swift` | modify | summary/breakdown anchor AXID 추가 |
| `DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeDetailView.swift` | modify | picker/header/list anchor AXID 추가 |
| `DUNE/Presentation/Activity/TrainingVolume/ExerciseTypeDetailView.swift` | modify | duplicated AXID 수정 + chart/list AXID 추가 |
| `DUNE/Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift` | modify | picker/chart/reward/history AXID 추가 |
| `DUNE/Presentation/Activity/Consistency/ConsistencyDetailView.swift` | modify | calendar/history/empty-state AXID 추가 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | modify | 새 AXID 상수 등록 |
| `DUNEUITests/Full/TodaySettingsRegressionTests.swift` | modify | settings 032~034 regression 추가 |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | modify | activity 035, 036, 039, 040, 041 regression 추가 |
| `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift` | modify | weekly stats / training volume surface assertions 보강 |
| `todos/032-*.md` ~ `todos/041-*.md` | rename + modify | status를 `done`으로 갱신하고 implementation/lane 기록 |
| `todos/101-ready-p2-e2e-phase0-page-backlog-index.md` | modify | 완료된 10개 surface 제거, open count 동기화 |
| `todos/107-done-p2-e2e-phase0-completed-surface-index.md` | modify | 완료 index에 10개 surface 추가 |

## Implementation Steps

### Step 1: Settings/Activity detail surface selector inventory 보강

- **Files**: Settings/Activity 대상 view 파일들, `DUNEUITests/Helpers/UITestHelpers.swift`
- **Changes**: 테스트에서 안정적으로 접근할 screen/picker/chart/list/row/toggle/save identifiers를 추가한다.
- **Verification**: `rg -n "accessibilityIdentifier" ...`로 새 surface anchor가 존재하는지 확인

### Step 2: Settings regression 확장으로 032~034 구현

- **Files**: `DUNEUITests/Full/TodaySettingsRegressionTests.swift`
- **Changes**:
  - Exercise Defaults 목록 진입/검색
  - Exercise Default edit 저장/재진입 검증
  - Preferred Exercises toggle/section 검증
- **Verification**: settings regression class targeted UI test 실행

### Step 3: Activity regression 확장으로 035~041 구현

- **Files**: `DUNEUITests/Full/ActivityExerciseRegressionTests.swift`, `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift`
- **Changes**:
  - Activity root surface anchor 검증
  - Training Readiness detail period/sub-score 검증
  - Weekly Stats period/chart/breakdown 검증
  - Training Volume chart + drill-down 검증
  - Exercise Type detail chart/recent session 검증
  - Personal Records timeline/reward/history 검증
  - Consistency calendar/history 검증
- **Verification**: activity regression class + chart regression class targeted UI test 실행

### Step 4: TODO and backlog reconciliation

- **Files**: `todos/032-*.md` ~ `todos/041-*.md`, `todos/101-*.md`, `todos/107-*.md`
- **Changes**: file rename, status/checkbox/implementation/lane update, open/completed index 이동
- **Verification**: `rg -n "032-|033-|034-|035-|036-|037-|038-|039-|040-|041-" todos/101-ready-p2-e2e-phase0-page-backlog-index.md todos/107-done-p2-e2e-phase0-completed-surface-index.md todos`

## Edge Cases

| Case | Handling |
|------|----------|
| Settings seeded state에 exercise default record가 없음 | 테스트 안에서 저장 후 재진입으로 persistence를 검증 |
| segmented picker label이 locale에 따라 흔들릴 수 있음 | AXID 또는 accessibilityValue를 기준으로 검증 |
| root screen AXID가 child CTA를 가릴 수 있음 | 상호작용 root가 아닌 안정 anchor에 screen AXID 배치 |
| iPad 레이아웃에서 Activity navigation tree가 달라짐 | 기존 `navigateToTab` / scroll helper와 stable AXID를 유지 |

## Testing Strategy

- Unit tests: 없음. 이번 변경은 UI surface selector와 UI regression 확장 중심이다.
- Integration tests:
  - `scripts/build-ios.sh`
  - `scripts/test-ui.sh --smoke`로 기존 PR lane 회귀 확인
  - targeted `xcodebuild test`로 `TodaySettingsRegressionTests`, `ActivityExerciseRegressionTests`, `ChartInteractionRegressionUITests` 실행
- Manual verification: 없음. seeded XCUI flow로 대체한다.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| root AXID 추가가 child control hittability를 다시 깨뜨림 | medium | high | screen marker를 비인터랙티브 anchor 또는 wrapper에만 부여 |
| settings persistence test가 CloudKit/SwiftData timing에 흔들림 | medium | medium | 저장 후 즉시 재진입 가능한 UI 상태만 검증하고 destructive clear는 최소화 |
| chart regression runtime 증가 | medium | medium | 기존 chart regression file에 surface assertion만 얹고 deep gesture는 기존 케이스를 재사용 |
| detached HEAD에서 커밋/ship 흐름이 꼬임 | medium | high | Work setup 초기에 `codex/` prefix branch를 생성하고 그 이후만 커밋 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 seeded UI infrastructure와 regression 패턴이 충분하지만, settings fixture가 비어 있어 테스트를 상태 생성형으로 작성해야 하고 몇몇 detail view는 아직 selector inventory가 부족해 실제 빌드/실행에서 미세 조정이 필요할 가능성이 있다.
