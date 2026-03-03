---
topic: agentic-coding-validation-time-reduction
date: 2026-03-04
status: implemented
confidence: high
related_solutions:
  - docs/solutions/testing/ui-test-infrastructure-design.md
  - docs/solutions/testing/2026-02-23-healthkit-permission-ui-test-gating.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-agentic-coding-validation-time-reduction.md
---

# Implementation Plan: Agentic Coding Validation Time Reduction

## Context

현재 병목은 PR 머지 이후 실행되는 UI 테스트와 main push 기반 중복 검증이다.
개발자 입장에서 피드백이 늦고, 실패 발견 시 롤백/재작업 비용이 증가한다.
목표는 "머지 후 단계 축소"와 "빠른 사전 검증"을 동시에 달성하면서 동기화/기존 기능 회귀 안전망을 유지하는 것이다.

## Requirements

### Functional

- PR 기준으로 빠른 검증 게이트를 실행한다.
- 기존 `pull_request closed`(merged) 기반 UI 테스트를 제거하고, PR 시점으로 이동한다.
- iOS/watch UI는 smoke 중심으로 축소 실행한다.
- nightly workflow는 full 회귀(단위 + UI) 역할을 유지한다.

### Non-functional

- 머지 후 자동 테스트 단계 수를 줄인다.
- CI 신호 품질(flaky 저감)을 유지한다.
- 기존 스크립트 인터페이스 호환성을 유지한다.

## Approach

`Tier 1(빠른 PR 게이트)`와 `Tier 2(야간 전체 회귀)`를 분리한다.

- Tier 1(PR): build + unit + iOS/watch UI smoke
- Tier 2(nightly): iOS/watch unit + iOS/watch full UI

구현은 기존 workflow/script를 최대한 재사용하면서 트리거/실행 프로파일만 조정한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 현행 유지 (머지 후 UI) | 변경 최소 | 병목 지속, 피드백 지연 | 기각 |
| PR에서 full UI 실행 | 회귀 강도 높음 | PR 대기시간 증가, flakiness 영향 확대 | 기각 |
| PR에서는 smoke, nightly full 유지 | 빠른 피드백 + 회귀 안전망 균형 | 프로파일 관리 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `.github/workflows/test-ui.yml` | Modify | 트리거를 PR 사전 검증용으로 전환, smoke 실행 |
| `.github/workflows/build-ios.yml` | Modify | main push 트리거 제거로 머지 후 중복 단계 축소 |
| `.github/workflows/test-unit.yml` | Modify | main push 트리거 제거로 머지 후 중복 단계 축소 |
| `scripts/test-ui.sh` | Modify | `--smoke` 옵션 추가(기존 옵션과 호환) |
| `scripts/test-watch-ui.sh` | Modify | `--smoke` 옵션 추가(기존 옵션과 호환) |

## Implementation Steps

### Step 1: PR 게이트 트리거 재정의

- **Files**: `.github/workflows/test-ui.yml`, `.github/workflows/build-ios.yml`, `.github/workflows/test-unit.yml`
- **Changes**:
  - `test-ui.yml`: `pull_request: types [opened, synchronize, reopened, ready_for_review]`로 전환
  - `test-ui.yml`: UI 테스트 명령을 smoke 프로파일로 변경
  - `build-ios.yml`/`test-unit.yml`: `push` 트리거 제거
- **Verification**:
  - YAML 문법 검증
  - 트리거 이벤트/경로 필터 정합성 확인

### Step 2: UI Smoke 실행 프로파일 도입

- **Files**: `scripts/test-ui.sh`, `scripts/test-watch-ui.sh`
- **Changes**:
  - `--smoke` 플래그 추가
  - iOS smoke default set: Dashboard/Activity/Wellness/Life/Settings smoke classes
  - watch smoke default set: WatchHome/WatchWorkoutStart smoke classes
  - 기존 `--only-testing`, `--skip-testing`, `--test-plan` 동작 유지
- **Verification**:
  - `bash -n` 구문 검증
  - 옵션 조합 파싱 확인(`--smoke` + 기존 옵션)

### Step 3: 품질 검증 및 문서화

- **Files**: 변경 파일 전체 + docs
- **Changes**:
  - 변경 diff 리뷰 및 위험 점검
  - solution 문서 작성 (testing 카테고리)
- **Verification**:
  - `bash -n scripts/test-ui.sh scripts/test-watch-ui.sh`
  - 필요 시 workflow 파일 정적 점검

## Edge Cases

| Case | Handling |
|------|----------|
| `--smoke`와 `--only-testing` 동시 사용 | 사용자 지정 `--only-testing` 우선, smoke 기본값은 주입하지 않음 |
| PR draft 단계에서 불필요 실행 | `ready_for_review` 포함, draft 중복 실행은 concurrency로 완화 |
| UI smoke만으로 놓칠 수 있는 회귀 | nightly full 회귀를 유지해 보완 |
| 동기화 관련 간접 회귀 | unit + watch sync 관련 테스트를 PR에서 계속 포함(기존 unit suite 유지) |

## Testing Strategy

- Unit tests: 해당 없음 (bash workflow/script 변경)
- Integration tests:
  - `bash -n scripts/test-ui.sh`
  - `bash -n scripts/test-watch-ui.sh`
- Manual verification:
  - workflow 파일 diff 검토
  - 필요 시 GitHub Actions에서 PR 기준 실행 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| smoke 범위 누락으로 PR 통과 후 회귀 발견 지연 | Medium | Medium | nightly full 유지 + smoke 대상 정기 조정 |
| 트리거 전환으로 기존 required check 이름/타이밍 영향 | Medium | Medium | workflow 이름 유지, 이벤트만 조정 |
| shell 옵션 파싱 회귀 | Low | Medium | `bash -n` + 옵션 조합 수동 점검 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 infra를 재사용하는 소규모 변경으로 목표(머지 후 단계 감소, 빠른 검증)와 리스크 통제가 균형적이다.
