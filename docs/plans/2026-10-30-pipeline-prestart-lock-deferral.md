---
topic: pipeline-prestart-lock-deferral
tags: [pipeline, retry, simulator-lock, audit]
date: 2026-10-30
category: plan
status: implemented
confidence: high
related_solutions:
  - docs/solutions/testing/2026-10-22-codex-ui-test-bounded-execution.md
  - docs/solutions/testing/2026-10-30-branch-core-validation-budget.md
---

# Implementation Plan: 실행 전 simulator lock 대기의 감사 분류

## Context

T05의 기존 pipeline 이력은 정상 성공 뒤 실제 launch timeout 124, 실행 전 lock busy exit 2를 모두 실패 횟수로 계산했다. 사용자는 별도 tooling PR을 검토·머지한 뒤에만 해당 분류를 적용하도록 명시적으로 허용했다. 원본 화면 worktree와 기존 기록은 이 작업에서 수정하지 않는다.

## Requirements

- 원본 attempts/status/log/hash를 수정하지 않는다. 부가 감사 분류만 저장한다.
- 표준 `scripts/test-ui.sh` 직접 호출, exit 2, 동일한 실행 전후 fingerprint, 정확히 한 줄인 lock timeout 출력과 로그 hash를 검증한다.
- 과거 receipt에는 실행 당시 소스·환경 증명이 없다. 자동 추정 대신 별도 감사 파일로 당시 실행 출처를 사람이 확인한다. 감사 내용과 증거 파일은 hash로 연결하고 검증 시 재확인한다.
- 검토한 두 소스 closure(a9d4cecc / 9a21f364)의 Git mode와 내용 hash를 허용한다. 알려지지 않은 소스·symlink·wrapper·추가 출력·unknown exit는 거부한다.
- 분류된 대기는 성공이 아니며 check/phase passed를 충족하지 못한다. 명령은 nonzero를 유지한다.
- 마지막 실제 실패에 대한 원인·해결·증거 및 내용/context 변화 의무를 유지한다. 실제 실패 두 번이면 대기 분류 유무와 무관하게 중단한다.
- 다음 실제 실행은 기존 표준 runner의 ownership·lock·deadline을 그대로 거친다.

## Approach

`codex-pipeline.py defer-lock`이 감사 파일과 원본 시도를 검증하고 `lock_deferrals`에 부가 기록을 저장한다. retry 계산과 status 표시에서만 유효한 부가 기록을 참조한다. deferred-only 이력 뒤에는 동일 입력 실행이 가능하지만 실제 실패가 있으면 그 실패를 기준으로 조건부 재시도를 검증한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 로그 문자열 자동 분류 | 간단함 | 당시 소스·환경을 증명하지 못함 | 제외 |
| runner attestation protocol | 향후 실행 증명 강화 | legacy 복구 불가, 실행기 범위 확대 | 제외 |
| 명시적 감사 + 제한된 소스 closure | 원본 보존, 검토 가능한 좁은 예외 | 당시 환경은 operator attestation 의존 | 선택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| scripts/codex-pipeline.py | 수정 | 감사 분류와 실패 횟수 계산, 상태 표시 |
| scripts/tests/test_codex_pipeline.py | 수정 | 진짜 파일 잠금과 악성/누락 증거 계약 |
| .codex/skill-compat.md | 수정 | 승인된 실행 전 대기 예외의 제한 |
| .codex/token-efficiency.md | 수정 | 감사 사용법과 신뢰 경계 |
| docs/plans/2026-10-30-pipeline-prestart-lock-deferral.md | 추가 | 계획과 검증 범위 |

## Implementation Steps

### Step 1: 감사 검증과 분류

- 표준 argv, source closure, 원본 log/attempt fingerprint 및 감사 근거를 검증한다.
- 원본 attempt는 유지하고 부가 기록만 원자적으로 저장한다.
- Verification: 실제 fixture repository lock busy와 위조·symlink·변조 거부 계약.

### Step 2: retry/check/status 통합

- 검증된 deferral만 failure budget에서 제외하며 마지막 실제 실패를 기준으로 remediation을 요구한다.
- check는 원본 마지막 실패를 계속 거부한다. status는 original status와 audited deferral을 구분한다.
- Verification: 실제 실패 1회/2회, 감사 후 이력·fingerprint 불변, 조건부 재시도 계약.

### Step 3: 문서와 소비자 검증

- `.claude/**`는 변경하지 않고 Codex adapter에 명시적 예외와 한계를 기록한다.
- 관련 소비자는 pipeline run/check/phase/report/status, CI test-ui의 기존 pipeline suite, plan-ui-tests의 CODEX_TOOLING 매핑이다. 새 helper 파일을 만들지 않아 매핑을 확대하지 않는다.
- Verification: Python pipeline/receipt/planner 계약, parity, diff check. shell 변경이 없어 shell 검사는 기존 표준 runner 정적 구문 검사로 한정한다.

## Edge Cases

| Case | Handling |
|------|----------|
| fake command / shell wrapper / post-start 추가 출력 | 감사 분류 거부 |
| missing/tampered log 또는 audit/reference evidence | 분류 거부 또는 이후 재시도 차단 |
| source closure 변경, symlink | 분류 거부 |
| actual timeout / build/test failure / unknown exit | 실제 실패 유지 |
| actual failure 한 번 + deferral | 실제 실패 근거가 있는 조건부 재시도만 허용 |
| actual failure 두 번 + deferral | 추가 실행 거부 |
| deferral-only | nonzero 유지, 성공 증거 생성 안 함 |

## Testing Strategy

- Python 계약은 임시 Git fixture와 파일 lock만 사용하며 simctl/Xcode를 호출하지 않는다.
- UI/build skip: 앱·runner boot/install/seed/selector·CI 실행 경로를 변경하지 않는다. UI 검증·새 캡처 대상 없음.
- 기존 실제 T05 receipt는 읽기만 하고 해당 scope의 재실행은 parent의 검토·별도 PR 머지 후 수행한다.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 과거 환경의 누락된 기계 증명 | 확실 | 무조건 자동 분류 불가 | operator-attested provenance를 명시하고 외부 근거 hash를 결합 |
| 동일 사용자에 의한 전체 store 위조 | 기존 신뢰 경계 | 증거 위조 | 암호학적 런타임 인증이라고 주장하지 않음 |
| 정상 runner 업데이트로 분류 무효 | 중간 | 보수적 차단 | 새 closure는 별도 검토 후 허용 |

## Confidence Assessment

- Overall: High. 실행기 동작을 건드리지 않고 기존 원자적 기록·worktree lock·fingerprint를 재사용한다.
- Init baseline: 9a21f364908c346205b70957f16d8883ecf0e84a, clean worktree.
- Review/Quality/Compound/Ship은 parent 담당이며 이 문서는 해당 게이트 승인을 뜻하지 않는다.

## Work verification record

- 새 감사 계약 7개 최초 실행: fixture가 macOS `/var` alias를 정규화하지 않아 7개 error. `Path.resolve()` 수정 후 같은 7개가 11.162초에 통과했다.
- 전체 pipeline 계약 최초 실행: 28개 중 25개 통과, 3개 error(72.436초). 새 legacy fixture 문자열 복원과 광범위 Popen mock 두 오류를 수정하고 해당 2개 재실행이 1.561초에 통과했다.
- 나머지 signal 계약은 고정 0.3초 뒤 receipt 생성 전에 SIGTERM을 전달해 실패했다. baseline에서 동일 실패를 입증한 것은 아니다. parent가 허용한 좁은 fixture 수정으로 running status+child PID가 기록될 때까지 최대 5초 기다리고, 실패 시 finally cleanup과 종료한 child group assertion을 유지한다.
- 위 원인에 대응한 변경 뒤 전체 pipeline 계약을 한 번 조건부 재검증한다. 실제 출력은 ignored `.codex-checks/pipeline/` receipt와 `.codex-checks/pipeline-lock/pipeline.json`에 기록한다.
- 소비자 확인: 기존 CI `ui-gate-contracts`가 동일 테스트 파일을 실행하고 `plan-ui-tests.py`의 정확한 CODEX_TOOLING 목록에 두 Python 파일이 이미 등록돼 있다. workflow·표준 UI runner는 변경하지 않는다.
- 초기 explicit py_compile이 만든 두 untracked pyc를 제거했다. 최종 planner는 iOS/watch 모두 `skip`, commands 빈 배열을 반환했다. 이를 실제 UI 검증 성공으로 보고하지 않는다.
