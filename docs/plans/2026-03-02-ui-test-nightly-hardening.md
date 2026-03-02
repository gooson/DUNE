---
topic: ui-test-nightly-hardening
date: 2026-03-02
status: implemented
confidence: high
related_solutions:
  - docs/solutions/testing/ui-test-infrastructure-design.md
  - docs/solutions/testing/2026-02-23-healthkit-permission-ui-test-gating.md
related_brainstorms:
  - docs/brainstorms/2026-03-02-ui-test-nightly-hardening.md
---

# Implementation Plan: UI Test Nightly Hardening

## Context

UI 테스트는 현재 PR 머지 시점 중심으로 실행되어 일일 회귀 감시가 약하다.  
또한 일부 테스트가 UI 텍스트에 의존하여 copy/localization 변경 시 false failure 가능성이 존재한다.

## Requirements

### Functional

- 매일 새벽 1회 자동 UI 테스트 실행 워크플로 추가
- 수동 실행 가능한 nightly workflow 제공
- 핵심 smoke UI 테스트를 접근성 식별자(AXID) 기반으로 강화
- 수동 성격 HealthKit 권한 테스트는 자동 회귀 범위에서 제외 유지

### Non-functional

- 테스트 flakiness 완화
- 기존 PR 머지 후 UI 테스트 파이프라인과 충돌 없이 공존
- 로그 artifact를 통한 실패 원인 추적 가능

## Approach

nightly 전용 workflow를 별도 추가하고, UI test runner 스크립트에 실행 모드 옵션을 보강한다.  
동시에 앱 코드와 UI 테스트 코드를 AXID 중심으로 정렬해 문자열 의존도를 낮춘다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 `test-ui.yml`에 schedule 추가 | 파일 수 증가 없음 | PR-merge/nightly 목적 혼재, 운영 가독성 저하 | 기각 |
| nightly 전용 workflow 분리 | 목적 분리, 운영 명확성 | workflow 파일 1개 추가 관리 필요 | 채택 |
| 텍스트 selector 유지 | 코드 변경 최소화 | localization/copy 변경 취약 | 기각 |
| AXID selector 전환 | 회귀 안정성 향상 | 앱 코드에 identifier 추가 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `.github/workflows/test-ui-nightly.yml` | Create | 매일 새벽 UI 테스트 자동 실행 workflow |
| `scripts/test-ui.sh` | Modify | `--only-testing`, `--test-plan` 옵션 및 실행 안정성 보강 |
| `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift` | Modify | picker 관련 AXID 추가 |
| `DUNE/Presentation/Wellness/WellnessView.swift` | Modify | 웰니스 add menu 항목 AXID 추가 |
| `DUNE/Presentation/Settings/SettingsView.swift` | Modify | Settings 검증용 AXID 추가 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | Modify | 신규 AXID 상수 추가 |
| `DUNEUITests/Helpers/UITestBaseCase.swift` | Modify | `sleep` 제거, 상태 기반 종료 대기 |
| `DUNEUITests/Launch/LaunchScreenTests.swift` | Modify | `sleep` 제거, 상태 기반 종료 대기 |
| `DUNEUITests/Smoke/ActivitySmokeTests.swift` | Modify | picker open/dismiss 검증 강화 |
| `DUNEUITests/Smoke/WellnessSmokeTests.swift` | Modify | menu/form 검증 AXID 전환 |
| `DUNEUITests/Smoke/LifeSmokeTests.swift` | Modify | assertion 강화 |
| `DUNEUITests/Smoke/SettingsSmokeTests.swift` | Modify | Settings 검증 AXID 전환 |

## Implementation Steps

### Step 1: Nightly workflow 도입

- **Files**: `.github/workflows/test-ui-nightly.yml`
- **Changes**:
  - `schedule` + `workflow_dispatch` 추가
  - 04:00 KST(19:00 UTC) 기준 cron 설정
  - nightly 로그 artifact 업로드
- **Verification**:
  - YAML 문법 검증
  - workflow 트리거/step 구성이 기존 UI workflow 패턴과 일치

### Step 2: UI runner 스크립트 확장

- **Files**: `scripts/test-ui.sh`
- **Changes**:
  - `--only-testing`(복수) 및 `--test-plan` 인자 지원
  - 기본 동작은 기존과 동일하게 `-only-testing DUNEUITests`
  - 병렬 실행 비활성화로 flakiness 완화
- **Verification**:
  - `bash -n scripts/test-ui.sh`
  - 옵션 파싱 경로 점검

### Step 3: AXID 보강 + smoke 테스트 강화

- **Files**:
  - `DUNE/Presentation/...` 3개 파일
  - `DUNEUITests/...` 관련 helper/smoke 파일
- **Changes**:
  - 앱 코드에 누락 AXID 추가
  - 문자열 selector를 AXID selector로 치환
  - `guard return` 기반 false pass 가능 구간을 assertion으로 변경
  - `Thread.sleep()` 제거
- **Verification**:
  - 정적 검색(`rg`)으로 식별자 연결 확인
  - 가능한 범위 UI test 실행

## Edge Cases

| Case | Handling |
|------|----------|
| GitHub Actions cron은 UTC 기준 | 주석으로 KST 변환 근거 명시 |
| HealthKit 권한 테스트 자동 실행 시 불안정 | manual gating 유지 |
| 로컬 CoreSimulator 서비스 오류 | 로그 근거로 환경 이슈 분리 보고 |

## Testing Strategy

- Unit tests: 대상 없음 (UI infra/workflow 변경 중심)
- Integration tests:
  - `bash -n scripts/test-ui.sh`
  - `scripts/test-ui.sh --only-testing DUNEUITests/Smoke/ActivitySmokeTests ...` 최소 실행 시도
- Manual verification:
  - GitHub Actions에서 nightly workflow 수동 실행(`workflow_dispatch`) 후 로그 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 메뉴 항목 AXID가 런타임 UI 트리에 반영되지 않을 가능성 | Medium | Medium | smoke 테스트 + 필요 시 메뉴 구조 fallback selector 병행 |
| simulator 환경 문제로 로컬 검증 실패 | High | Medium | CI runner 기준 검증 및 로그 artifact 기반 확인 |
| nightly 실행 시간 증가 | Medium | Low | timeout 90분 설정, 필요 시 only-testing 분할 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 UI test infra 패턴(AXID/CI gating)과 동일한 방향으로 확장했으며, 영향 범위가 명확하고 rollback 비용이 낮다.
