---
tags: [codex-pipeline, simulator-lock, retry-budget, operator-attestation, process-readiness]
category: testing
date: 2026-10-30
severity: important
related_files:
  - scripts/codex-pipeline.py
  - scripts/tests/test_codex_pipeline.py
  - .codex/skill-compat.md
  - .codex/token-efficiency.md
related_solutions:
  - docs/solutions/testing/2026-10-22-codex-ui-test-bounded-execution.md
  - docs/solutions/testing/2026-10-30-branch-core-validation-budget.md
---

# Solution: 실행 전 잠금 대기를 실제 실패와 분리하는 감사 기록

## Problem

UI 검사의 실제 launch timeout 뒤 다른 worktree가 simulator 잠금을 보유해 다음 명령이 시작 전에 exit 2로 끝났다. 기존 pipeline은 두 기록을 모두 실패로 세어 실제 조건부 재검증을 차단했다.

### Symptoms

- 표준 runner의 lock busy 한 줄만 남고 boot/build/test는 시작되지 않았다.
- 기존 check ID의 실패 한도가 소진돼 다음 화면 검사를 실행할 수 없었다.
- 새 ID나 이력 삭제로 우회하면 실제 실패 제한과 검증 출처가 사라진다.

### Root Cause

실행 종료 상태만으로 실패 횟수를 계산했다. 과거 receipt에는 당시 환경과 실행 소스를 독립적으로 연결할 증거가 없어 로그 문자열만으로 자동 면제할 수도 없다.

## Solution

사용자가 승인한 별도 tooling 변경으로 `defer-lock` 감사를 추가했다. 원본 attempts/status/log/hash는 보존하고 부가 분류만 저장한다. 성공 이후에도 감사 대상 이력과 로그가 바뀌지 않도록 유지한다.

| File | Change | Reason |
|------|--------|--------|
| `scripts/codex-pipeline.py` | 엄격한 감사 검증과 실제 실패 기준 retry 계산 | 대기는 성공이나 실패 횟수 초기화가 아님 |
| `scripts/tests/test_codex_pipeline.py` | 진짜 잠금 충돌·위조·변경·경계 계약 | boot/build/test 없이 pre-start 경로 확인 |
| Codex adapter 문서 | 제한된 예외·읽기 전용 준비 절차 | 원본 Claude 설정과 실제 실패 제한 유지 |

검증 조건은 직접 표준 runner argv, failed exit 2, 실행 전후 동일 fingerprint, 정확한 단일 lock 메시지, 원본 시도·로그·근거 hash, 검토한 pre-lock source closure다. unknown 출력·추가 실패 원인·symlink·변경된 근거는 거부한다.

`source_revision`과 과거 환경의 연결은 담당자의 **operator attestation**이다. 이것을 암호학적 런타임 증명이나 같은 사용자의 store 위조를 막는 인증으로 표현하지 않는다. 새로운 source closure는 검토 전까지 차단한다.

후속 실행은 잠금을 정상 획득해야 한다. 실제 실패가 하나 있으면 그 실패의 원인·해결·증거와 입력 변경을 요구하고, 실제 실패가 두 번이면 중단한다. 감사된 대기는 `check` 또는 phase passed를 만족시키지 않는다.

### Verification

- pipeline 28, planner 25, receipt 12: 총 65개 targeted Python 검사 통과.
- parity·shell 구문·diff 검사 통과. 후속 문구 변경은 읽기 전용 recipe 실행으로 원본 receipt 불변성과 hash 일치를 확인했다.
- 기존 signal 테스트의 고정 0.3초 대기를 running receipt와 child PID의 bounded readiness로 바꿔 실제 interrupt/소유 자식 정리를 검사했다.
- 앱·Swift·기기 선택·설치·seed·CI 변경은 없다. native build/UI/capture는 소비자 분석에 따라 skipped이며 이 결과로 T05/T06 앱 검사를 통과 처리하지 않는다.

## Prevention

- 기존 ID와 원본 실패 기록을 유지한다. 단순 로그 일치나 담당자 부재로 대기를 자동 승인하지 않는다.
- 감사할 source와 환경의 확인 근거를 동결하고, 현재 HEAD를 과거 실행 소스로 자동 대입하지 않는다.
- 진입 전 잠금 확인을 사용한다면 shell이 nonzero에서 실제 중단하는지 확인한다. 확인과 실행 사이의 경쟁도 표준 잠금으로 처리한다.
- process signal 검사는 고정 sleep 대신 실제 소유 process 준비 상태를 제한 시간 안에 확인한다.

## Lessons Learned

실행되지 않은 검사는 성공도 앱 실패도 아니다. 보존한 실패와 감사 분류를 분리하면 재시도 제한을 약화하지 않고 검증을 이어갈 수 있다. 데이터가 없는 과거 환경은 자동 증명으로 꾸미지 않고 신뢰 경계를 명시해야 한다.
