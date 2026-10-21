---
tags: [codex, ui-test, xcodebuild, simulator, timeout, agent-workflow]
category: testing
date: 2026-10-22
status: implemented
severity: important
related_files:
  - AGENTS.md
  - .codex/skill-compat.md
  - .codex/token-efficiency.md
  - scripts/test-ui.sh
  - scripts/test-watch-ui.sh
  - scripts/lib/command-deadline.py
  - scripts/lib/simulator-test-lock.py
  - scripts/lib/simulator-boot.sh
  - scripts/lib/simulator-worktree.sh
  - scripts/lib/worktree-simulator-registry.py
related_solutions:
  - docs/solutions/testing/2026-03-30-ci-simulator-boot-timeout.md
  - docs/solutions/testing/2026-03-29-ui-test-force-kill-cascade-prevention.md
---

# Solution: Codex UI 테스트 실행 점유 제한

## Problem

### Symptoms

- Codex 작업이 UI 검증을 시작한 뒤 수십 분에서 수시간 동안 끝나지 않고, 같은 테스트·시뮬레이터 상태를 반복 조회했다.
- 보관된 Health 세션 296개를 모두 조회했고, 293개의 최근 최대 10턴을 읽었다. 과대형 기록 3개는 도구 크기 제한으로 최근 1턴만 재조회했다. 읽힌 기록에서 UI/시뮬레이터 관련 명령 1,536회(45개 세션)가 확인됐고, 16개 세션에 10분을 넘긴 단일 명령이 있었다. 디자인 개편 작업 한 세션에는 관련 명령 316회가 있었다. 명령 집계에는 짧은 `simctl` 조회도 포함되며, 모든 과거 턴이나 실제 CPU 점유율을 뜻하지 않는다.
- 사용자에게 빠른 종료 경계가 없고, Xcode 결과 작성이 멈춘 뒤에도 로그와 프로세스를 반복 확인하는 패턴이 있었다.

### Root Cause

- `xcodebuild`의 `-maximum-test-execution-time-allowance`는 **각 XCTest case**의 실행 시간을 제한한다. 테스트 전 빌드·시뮬레이터 잠금과 부팅·테스트 발견·종료 후 `.xcresult` 작성에는 상한이 없었다.
- 저장소 시뮬레이터 잠금은 대기 시간을 지정하지 않으면 무기한 기다렸다.
- `simulator-boot.sh`의 fallback은 이 Mac에 설치되지 않은 `timeout` 명령에 의존했고 `bootstatus` 자체도 무한 대기할 수 있었다.
- 에이전트가 raw `xcodebuild`, 별도 로그 이름, 추가 기기를 반복 사용하며 기존의 변경 범위 기반 검증 정책을 우회했다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `scripts/lib/command-deadline.py` | 소유한 프로세스 그룹을 전체 실행 시간과 로그 무갱신 시간으로 제한하고 timeout 시 종료 | 빌드부터 결과 정리까지 상한 부여 |
| `scripts/test-ui.sh`, `scripts/test-watch-ui.sh` | focused/smoke 30분, full 3시간 기본 deadline. 환경 변수로 사전 조정 가능 | 장시간 점유를 유한하게 제한 |
| `scripts/lib/simulator-test-lock.py` | UI 실행에서 기본 60초 잠금 대기 | 다른 워크트리 작업 뒤에 무한 대기 방지 |
| `scripts/lib/simulator-boot.sh` | `simctl boot`, `bootstatus`, 목록 조회에 Python deadline 적용 | CoreSimulator 정체와 누락된 `timeout` 명령 해결 |
| `scripts/lib/simulator-worktree.sh`, `scripts/lib/worktree-simulator-registry.py` | 조회·clone·삭제 명령의 제한 시간과 Watch clone의 소유권 기반 재생성 | iPhone→Watch 전환 시 오래된 Watch 인스턴스 누적 방지 |
| `AGENTS.md`, `.codex/skill-compat.md`, `.codex/token-efficiency.md` | raw UI `xcodebuild`와 중복 실행 제한, selector·기기·plan 선결정, timeout 실패 분류 | 에이전트가 비용 큰 경로를 반복하지 않도록 함 |

### Key Code

```sh
scripts/test-ui.sh --only-testing DUNEUITests/DashboardSmokeTests
DUNE_UI_TEST_WALL_TIMEOUT=2400 scripts/test-ui.sh --only-testing DUNEUITests/LongFlowTests
```

기본 deadline은 한 명령 전체에 적용되고, 테스트 로그가 15분간 갱신되지 않아도 종료한다. 만료 시 exit 124이며 테스트 통과로 취급하지 않는다. 시뮬레이터 잠금을 60초 안에 얻지 못하면 다른 실행의 종료를 기다리는 대신 실패 지점을 보고한다.

중첩 deadline은 바깥 실행의 프로세스 그룹을 유지한다. 바깥 watchdog은 정상 종료·실패·timeout·interrupt 이후에도 남은 자손을 정리한다. registry의 `simctl`도 같은 helper를 사용하며, 부팅 한 시도의 deadline에는 `bootstatus`와 fallback 조회 시간이 모두 포함된다.

Watch 기기 조회가 실패하면 이름 기반 실행으로 우회하지 않는다. clone 명령이 실패하면 생성 전 목록과 정확한 clone 이름을 대조해 부분 생성 기기를 기록하거나 수동 정리 표식을 남긴다. 확인할 수 없는 상태에서는 공유 원본 기기로 fallback하지 않고 실행을 중단한다.

## Prevention

- UI 테스트는 영향받는 selector와 기기 하나부터 실행한다. 전체 suite는 사용자가 명시적으로 요청한 경우에만 실행한다.
- 하나의 실행이 진행 중이면 결과를 기다리고 같은 명령을 복제하지 않는다. 무출력 상태 조회는 제한된 간격으로만 한다.
- iPhone 다음 Watch 검증은 iPhone runner의 종료·receipt를 확인한 뒤 시작한다. Watch runner는 동일 worktree의 기록된 Watch clone만 삭제하고 다시 생성한다. 삭제 실패나 소유권 불명 상태는 검증 실패로 처리한다.
- timeout은 실패 증거로 보존한다. 마지막 testcase, 빌드·부팅·결과 정리 중 정체 위치를 확인한 뒤 원인이 바뀐 경우에만 재시도한다.
- UI 실행기를 변경할 때 프로세스 종료·잠금 대기·정확한 selector receipt의 계약 테스트를 함께 실행한다.

## Lessons Learned

- Apple의 [XCTest executionTimeAllowance](https://developer.apple.com/documentation/xctest/xctestcase/executiontimeallowance)는 case별 제한이므로 host command deadline을 별도로 둬야 한다.
- Apple은 [개발 중 관련 테스트를 좁혀 실행하고 통합 시 영향받는 target을 확대](https://developer.apple.com/documentation/xcode/running-tests-and-interpreting-results)하도록 안내한다. 실행 횟수와 범위를 source diff로 정해야 한다.
- [OpenAI Docs의 2026년 Codex 지침](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra)은 항상 전체 문서를 읽거나 불필요한 테스트를 반복하는 지침을 줄이고, 작업별 완료 조건을 분명히 하라고 권한다. 프로젝트 정책은 이 판단 경계를 짧게 유지한다.
