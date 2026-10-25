---
tags: [codex, claude, tokens, session-audit, screen-lock, simulator, ui-testing]
category: testing
date: 2026-10-25
severity: important
related_files: [scripts/audit-agent-sessions.py, scripts/lib/ui-host-state.py, scripts/test-ui.sh, scripts/test-watch-ui.sh, .codex/ui-execution.md]
related_solutions: [../architecture/2026-09-26-codex-token-efficiency.md]
---

# Solution: 세션 usage 집계와 UI 호스트 진단 분리

## Problem

장기 디자인·UI 작업은 반복 대기로 모델 호출이 누적되고, 종료 보고에는 Mac 화면 잠금·저장소 실행권 점유·Simulator 장애가 섞였다. 실제 사용량과 장애 분류를 함께 확인할 재현 가능한 도구가 필요했다.

### Symptoms

3주 Health usage 입력+출력 40.93억 중 입력 캐시율은 98.28%였다. 큰 총량만으로 실제 과금이나 낭비를 판단할 수 없었다. 동일 process 대기 호출 42회 사례가 있었고, 화면 잠금으로 설명한 미완료와 저장소 lock 미완료가 각각 확인됐다.

### Root Cause

usage 포맷의 중복·누적값·캐시/추론 부분집합을 구분하지 않으면 집계가 왜곡된다. UI 실행 전 호스트 상태 증거도 없어서 assistant의 원인 설명을 실제 환경 원인으로 오해하기 쉬웠다. 모든 UI 실패의 근본 원인을 이번 조사로 입증한 것은 아니다.

## Solution

| File | Change | Reason |
|---|---|---|
| `scripts/audit-agent-sessions.py` | 기간별 request/message usage, 압축 archive, 중복 제거 | 원문 일괄 로드 없이 재현 가능한 수치 확보 |
| `scripts/lib/ui-host-state.py` | Aqua 호출 manager, 현재 콘솔 사용자, host lock 진단 | 실행 가능성과 구분된 호스트 증거 |
| iOS/Watch UI runner | 실행권 획득 뒤 `.host.json` sidecar | 진단 실패가 본래 실행을 막지 않도록 함 |
| Codex adapter | 대기 호출 절감·독립 작업 진행·상세 진단 문서 진입점 | 중복 지침과 전체 작업 중단 감소 |

### Key Code

```sh
python3 scripts/lib/command-deadline.py --seconds 5 -- \
  python3 scripts/lib/ui-host-state.py --runner ios --output "$HOST_STATE_FILE"
```

실행기는 위 진단 실패 시 안내 후 preflight를 계속한다. 각 외부 조회는 1.5초 제한이며, 잠금 값이 누락·충돌·다른 사용자이면 `unknown`이다. raw registry는 저장하지 않는다.

집계 11개·진단 5개·기존 runner 5개 계약 테스트와 shell/parity 검사가 통과했다. 후속 별도 기기 실험에서 잠긴 Mac의 iPhone·Watch XCTest가 각각 1개 통과했고 새 PNG 6장을 확보했다. 별도 worktree 범위를 명시적으로 지원하면서도 동일 worktree 잠금은 유지했다. 실제 Watch 준비 단계에서 발견한 registry → deadline의 잠금 FD 손실을 수정해 통과했다. **잠금 해제 비교군과 실사용 절감률은 별도 검증 범위다.**

## Prevention

- cache read/write는 입력 안에, reasoning은 출력 안에 포함한다. 세션 마지막 cwd 대신 usage 시점으로 프로젝트를 귀속한다.
- 이미지가 포함된 output bytes를 토큰으로 환산하지 않는다. interruption·compaction·미완료 보고를 구분한다.
- UI 실패 시 `.codex/ui-execution.md`에서 단계와 재개 조건을 확인한다. host lock만으로 Simulator XCTest 불가를 단정하지 않는다.
- 대기 중 독립 작업은 진행하되 미검증 UI 게이트는 통과시키지 않는다. 원인이 바뀌지 않았다면 반복 실행하지 않는다.

## Lessons Learned

높은 캐시율은 요청 수가 적다는 뜻이 아니다. 같은 대기 상태에서도 긴 컨텍스트가 반복 처리될 수 있다. 반대로 많은 총 토큰을 모두 낭비라고 부를 수도 없다. 절감 효과는 동급 작업의 호출 수·새 입력·출력·완료 품질로 비교해야 한다.

전체 수치·공식 자료·남은 검증은 [감사 보고서](../../reviews/2026-10-25-session-efficiency-audit.md)에 기록했다.


### 후속 실행기 교정

기기가 분리돼도 repository 전역 잠금 때문에 실행하지 못했던 경로에 명시적 `DUNE_SIM_TEST_LOCK_SCOPE=worktree`를 추가했다. 기본은 repository이며 linked worktree만 opt-in을 허용한다. 구버전 runner의 동일 worktree 점유는 추가 잠금으로 감지할 수 없으므로 활성 프로세스의 작업 경로·UDID도 확인한다.

`command-deadline.py`와 `worktree-simulator-registry.py`는 primary/secondary 잠금 FD를 모두 `pass_fds`로 전달한다. 환경 변수만 전달하고 실제 FD를 닫으면 nested deadline이 `Bad file descriptor`로 실패한다. registry는 닫힌/잘못된 FD를 무시하지 않고 거부한다. 기기 부팅 실패로 보이는 오류가 실제로는 호스트 프로세스 전달 계약의 실패일 수 있다.
