---
topic: vision-window-placement-smoke
date: 2026-03-16
status: implemented
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-08-visionos-window-placement-planner.md
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-vision-pro-production-roadmap.md
---

# Implementation Plan: Vision Window Placement Smoke

## Context

`todos/107-ready-p2-vision-window-placement-runtime-validation.md`는 `VisionWindowPlacementPlanner`와 `defaultWindowPlacement` wiring 이후에도 실제 spatial arrangement를 반복 가능하게 검증할 방법이 없어서 남아 있다. 현재는 simulator/device에서 수동으로 quick action을 눌러야 하고, 검증 결과도 TODO 메모 수준에 머물러 있어 `020`, `023`의 잔여 범위를 줄이기 어렵다.

이번 배치는 full visionOS UI harness를 새로 만드는 대신, launch argument 기반 smoke path와 screenshot 캡처 스크립트를 추가해 primary placement를 재현 가능하게 만든다. true no-anchor fallback은 별도 residual TODO로 분리해 scope를 명확히 남긴다.

## Requirements

### Functional

- DUNEVision이 launch argument로 dashboard/chart3d window를 자동으로 순서대로 열 수 있어야 한다.
- simulator mock data와 함께 smoke flow를 재현하고 screenshot artifact를 남길 수 있어야 한다.
- `todos/107-*`의 primary placement 검증 결과를 문서/TODO에 남기고, 남은 fallback scope를 별도 TODO로 분리해야 한다.

### Non-functional

- launch argument 해석은 pure helper로 두어 unit test로 고정할 수 있어야 한다.
- shared source 새 로직은 기존 `VisionWindowPlacementPlanner` 패턴을 따라 visionOS app binding과 분리한다.
- 새로운 사용자 대면 문자열은 추가하지 않고, debug/smoke 상태는 shell/script와 log 중심으로 남긴다.

## Approach

`VisionWindowPlacementPlanner`에 smoke configuration helper를 추가하고, `VisionContentView`는 해당 설정이 켜졌을 때만 mock data seed와 multi-window open sequence를 자동 실행한다. 별도 shell script는 visionOS simulator build/install/launch/screenshot까지 한 번에 수행해 TODO 증빙에 바로 사용할 수 있는 artifact를 만든다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| visionOS 전용 XCUITest target 추가 | 장기적으로 가장 강한 자동화 | 새 test target, scheme, CI lane까지 범위가 커짐 | 기각 |
| 코드 변경 없이 수동 QA note만 남김 | 가장 빠름 | 재현성과 증빙 품질이 낮고 TODO를 다시 열 가능성이 큼 | 기각 |
| launch-arg smoke + simulator screenshot script | 현재 구조를 크게 바꾸지 않고 반복 가능한 검증 artifact 확보 가능 | no-anchor fallback은 완전 자동화가 어렵다 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift` | modify | smoke launch configuration helper 추가 |
| `DUNETests/VisionWindowPlacementPlannerTests.swift` | modify | smoke configuration parsing/unit coverage 추가 |
| `DUNEVision/App/VisionContentView.swift` | modify | smoke mode에서 mock seed + window auto-open sequence 실행 |
| `scripts/vision-window-placement-smoke.sh` | add | build/install/launch/screenshot automation script 추가 |
| `todos/107-ready-p2-vision-window-placement-runtime-validation.md` | modify | 완료 근거 또는 scope split 반영 |
| `todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md` | modify | runtime validation 완료 및 남은 residual scope 반영 |
| `todos/023-in-progress-p2-vision-phase4-remaining.md` | modify | window placement residual scope 재정리 |
| `todos/144-*.md` | add | no-anchor fallback residual manual scope를 별도 TODO로 분리 |
| `docs/solutions/testing/2026-03-16-vision-window-placement-smoke.md` | add | smoke workflow와 artifact 기반 검증 패턴 문서화 |

## Implementation Steps

### Step 1: Add testable smoke configuration

- **Files**: `VisionWindowPlacementPlanner.swift`, `VisionWindowPlacementPlannerTests.swift`
- **Changes**:
  - launch arguments를 해석하는 `VisionWindowPlacementSmokeConfiguration`을 추가한다.
  - default open window 순서와 mock seed 여부를 pure helper로 고정한다.
  - unit test에서 disabled/enabled/custom output path 수준까지 검증한다.
- **Verification**:
  - `VisionWindowPlacementPlannerTests`가 smoke config parsing 결과를 검증한다.

### Step 2: Wire auto-open smoke flow into DUNEVision

- **Files**: `VisionContentView.swift`
- **Changes**:
  - smoke config가 켜진 경우 1회성 task로 mock data seed 후 dashboard window + chart3d window를 순서대로 연다.
  - 뷰 생명주기에 맞춰 task 중복 실행과 disappear 시 누수를 막는다.
- **Verification**:
  - visionOS build가 통과하고, launch 시 open sequence가 log/runtime에서 중복 없이 실행된다.

### Step 3: Add reproducible simulator smoke script and backlog updates

- **Files**: `scripts/vision-window-placement-smoke.sh`, 관련 TODO/solution 문서
- **Changes**:
  - simulator 선택, boot, install, launch argument 전달, screenshot 캡처를 수행하는 script를 추가한다.
  - smoke 결과로 닫히는 TODO와 residual fallback TODO를 정리하고, `020`/`023`의 남은 범위를 업데이트한다.
- **Verification**:
  - script 실행으로 screenshot artifact가 생성된다.
  - TODO 파일 상태/updated 날짜가 naming/frontmatter 규칙과 일치한다.

## Edge Cases

| Case | Handling |
|------|----------|
| smoke launch가 여러 번 트리거됨 | `VisionContentView` 내부 1회 실행 guard로 중복 open 방지 |
| simulator에 기존 app instance가 살아 있음 | script에서 terminate 후 relaunch |
| mock seed가 실패함 | smoke는 계속 진행하되 stderr/log와 exit code로 실패를 노출 |
| no-anchor fallback을 simulator에서 완전 재현하기 어려움 | residual TODO로 분리하고 이번 batch scope에서 명시적으로 제외 |

## Testing Strategy

- Unit tests: `VisionWindowPlacementPlannerTests`에 smoke configuration parsing 케이스 추가
- Integration tests: `scripts/build-target.sh --scheme DUNEVision --platform visionos`
- Manual verification: `scripts/vision-window-placement-smoke.sh` 실행 후 screenshot artifact를 확인하고 TODO/solution에 결과 기록

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| visionOS simulator boot/install가 로컬 환경마다 불안정 | medium | medium | 기존 `simctl` fallback 패턴을 재사용하고 failure summary를 명확히 출력 |
| auto-open timing이 너무 빠르거나 느려 screenshot이 불안정 | medium | medium | script에서 configurable delay와 sequential sleep을 둔다 |
| residual fallback scope를 과도하게 닫아버릴 위험 | low | high | no-anchor fallback은 별도 TODO로 분리하고 문서에 근거를 남긴다 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 planner와 simulator script 패턴이 이미 있어 구현은 명확하다. 다만 visionOS simulator의 multi-window screenshot이 환경마다 다를 수 있어 smoke timing과 residual scope 분리가 핵심이다.
