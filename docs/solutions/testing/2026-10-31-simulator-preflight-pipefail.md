---
tags: [ci, simulator, pipefail, sigpipe, grep, preflight]
category: testing
date: 2026-10-31
status: implemented
related_files:
  - scripts/lib/simulator-boot.sh
  - scripts/tests/test-simulator-boot.py
related_solutions:
  - docs/solutions/testing/2026-04-06-ci-simulator-boot-hardening.md
---

# 시뮬레이터 목록 조회의 조기 파이프 종료로 인한 기기 누락 오판

## Problem

[PR #874의 Unit Tests 실행](https://github.com/gooson/DUNE/actions/runs/41093919985/job/124194615899)은 앱 테스트 시작 전에 Watch UDID가 없다는 사전 검사 오류로 종료했다. 직후 진단에는 같은 UDID가 존재했다.

대용량 목록을 내보내는 가짜 `simctl`로 같은 증상을 재현했다. `set -o pipefail` 아래에서 `simctl list devices | grep -qF "$udid"`는 일치 행을 찾은 `grep`이 먼저 종료하면 생산자에 SIGPIPE를 일으킬 수 있다. 전체 파이프라인은 실패하고 존재하는 기기를 없다고 판정한다. 기존 원격 로그에는 생산자의 종료 코드가 없으므로 원격의 실제 signal까지 확정하지는 않는다.

## Solution

사전 검사를 `grep -F "$udid" >/dev/null`로 바꿔 일치 여부를 확인하면서 목록 전체를 소비한다. 생산자의 오류와 실제 기기 누락은 계속 실패로 처리한다. 부팅 시간 제한·재시도 횟수·CI 테스트 범위는 유지한다.

## Verification

수정 전에는 존재하는 기기 테스트가 `not found in device list`로 실패하고 직후 진단에는 같은 기기가 출력됐다. 수정 후 `PYTHONDONTWRITEBYTECODE=1 python3 -B scripts/tests/test-simulator-boot.py`의 3개 테스트가 통과했다.

- 파이프 버퍼보다 큰 목록에서 존재하는 기기 승인
- 같은 크기의 목록에서 없는 기기 거부
- 정지한 bootstatus의 기존 전체 시도 시간 제한 유지

`bash -n scripts/lib/simulator-boot.sh`도 통과했다. 이 검증은 실제 시뮬레이터 서비스를 사용하지 않는다. 후속 원격 결과는 [PR #874 검사](https://github.com/gooson/DUNE/pull/874/checks)에서 확인한다.

## Prevention

`pipefail`을 사용하는 조회 파이프라인에서는 생산자가 종료하기 전에 소비자가 출력을 닫는 `grep -q` 등의 사용을 검토한다. 목록 회귀 테스트는 작은 단일 행뿐 아니라 일치 행 뒤에 파이프 버퍼를 초과하는 출력이 남는 경우를 포함한다.

## Lessons Learned

일치 행을 찾았다는 사실과 생산자 명령의 성공은 별개다. 실제로 존재하는 기기를 다시 생성하거나 서비스 전체를 재시작하기 전에 목록 판정 파이프라인의 종료 상태를 확인한다.
