---
tags: [ci, github-actions, smoke-test, nightly-regression, pull-request, validation-time]
category: testing
date: 2026-03-04
severity: important
related_files:
  - .github/workflows/build-ios.yml
  - .github/workflows/test-unit.yml
  - .github/workflows/test-ui.yml
  - scripts/test-ui.sh
  - scripts/test-watch-ui.sh
related_solutions:
  - docs/solutions/testing/ui-test-infrastructure-design.md
  - docs/solutions/testing/2026-02-23-healthkit-permission-ui-test-gating.md
---

# Solution: PR Fast Gate + Nightly Full Regression 분리

## Problem

머지 이후에 실행되는 UI 테스트와 main push 기반 중복 검증 때문에 피드백이 늦고, 실패 감지가 병합 후로 밀리는 문제가 있었다.

### Symptoms

- PR merge 후에야 UI 테스트가 시작되어 실패 발견이 늦음
- build/unit이 PR과 main push 양쪽에서 중복 실행되어 검증 단계가 길어짐
- 개발자 기준 "변경 안전성 확인" 리드타임이 증가

### Root Cause

테스트 계층(Tier) 분리가 명확하지 않았다.
PR 사전 게이트와 머지 후 회귀 감시가 혼재되어, 빠르게 판단해야 할 단계와 넓게 감시해야 할 단계가 분리되지 않았다.

## Solution

PR에서는 빠른 게이트(특히 UI smoke)만 실행하고, 전체 회귀는 nightly로 유지하도록 분리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `.github/workflows/test-ui.yml` | `pull_request.closed` 기반 실행을 PR 사전 실행(`opened/synchronize/reopened/ready_for_review`)으로 전환 | 머지 전에 실패를 검출하기 위함 |
| `.github/workflows/test-ui.yml` | iOS/watch 실행 명령을 `--smoke` 프로파일로 변경 | PR 검증 시간을 단축하면서 핵심 흐름만 점검 |
| `.github/workflows/build-ios.yml` | `push(main)` 트리거 제거 | 머지 후 중복 빌드 단계 축소 |
| `.github/workflows/test-unit.yml` | `push(main)` 트리거 제거 | 머지 후 중복 테스트 단계 축소 |
| `scripts/test-ui.sh` | `--smoke` 옵션 추가 (5개 iOS smoke suite) | workflow에서 빠른 프로파일 선택 가능 |
| `scripts/test-watch-ui.sh` | `--smoke` 옵션 추가 (2개 watch smoke suite) | watch 검증도 동일 전략 적용 |

### Key Code

```yaml
# .github/workflows/test-ui.yml
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
```

```bash
# scripts/test-ui.sh
if [[ "$SMOKE_MODE" -eq 1 ]]; then
  TEST_CMD+=(-only-testing DUNEUITests/Smoke/DashboardSmokeTests)
  TEST_CMD+=(-only-testing DUNEUITests/Smoke/ActivitySmokeTests)
  ...
fi
```

## Prevention

PR 게이트와 회귀 감시를 역할 기반으로 유지한다.

### Checklist Addition

- [ ] 머지 후에만 실행되는 필수 테스트가 새로 추가되지 않았는지 확인
- [ ] PR 게이트는 smoke/핵심 경로 중심으로 유지되는지 확인
- [ ] 전체 회귀는 nightly에서 계속 커버되는지 확인

### Rule Addition (if applicable)

현재 규칙 추가는 보류. 동일 패턴의 CI 변경 시 본 문서를 우선 참조한다.

## Lessons Learned

검증시간 단축은 단순히 테스트를 줄이는 것이 아니라, "언제 어떤 강도로 실행할지"를 분리하는 것이 핵심이다.
PR은 빠른 결정, nightly는 넓은 감시라는 역할 분리가 병목 감소와 안전성의 균형을 만든다.
