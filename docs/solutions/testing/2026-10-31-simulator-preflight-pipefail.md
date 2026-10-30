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

사전 검사에서 stdout 목록 전체를 수집한 뒤 `grep -F "$udid" >/dev/null`로 일치 여부를 확인한다. 조회가 실패하면 종료 코드와 stderr를 보존하고 `device lookup failed`로 보고한다. 조회가 성공한 경우에만 실제 기기 누락 여부를 판정한다. 부팅 시간 제한·재시도 횟수·CI 테스트 범위는 유지한다.

## Verification

수정 전에는 존재하는 기기 테스트가 `not found in device list`로 실패하고 직후 진단에는 같은 기기가 출력됐다. 조회 자체의 실패도 기기 누락으로 보고했다. 수정 후 `PYTHONDONTWRITEBYTECODE=1 python3 -B scripts/tests/test-simulator-boot.py`의 4개 테스트가 통과했다.

- 파이프 버퍼보다 큰 목록에서 존재하는 기기 승인
- 같은 크기의 목록에서 없는 기기 거부
- 조회 오류와 deadline 종료 코드(17·124)를 기기 누락과 구분하고 stderr 보존
- 정지한 bootstatus의 기존 전체 시도 시간 제한 유지

`bash -n scripts/lib/simulator-boot.sh`도 통과했다. 이 검증은 실제 시뮬레이터 서비스를 사용하지 않는다. 후속 원격 결과는 [PR #874 검사](https://github.com/gooson/DUNE/pull/874/checks)에서 확인한다.

## 원격 검증 상태와 재개 조건

`1f54cf8f`의 iOS 빌드는 통과했지만 [단위 테스트 재시도](https://github.com/gooson/DUNE/actions/runs/41095960861/job/124201658851)도 Watch 사전 조회에서 실패했다. 앱 테스트는 시작되지 않았다. 이 실행에서는 초기 진단에 존재하던 watchOS 27 런타임이 iOS 부팅 후 목록에서 사라졌고, Watch 기기는 `runtime profile not found using “System” match policy`로 표시됐다. 파이프 조기 종료 개선만으로 원격 문제가 해결됐다고 볼 수 없다.

원격 실행은 최초 1회와 수정 후 재시도 1회를 사용했다. 사용자 실행 규칙의 동일 원인 재시도 한도에 따라 이 경로는 중단하고 PR을 머지하지 않는다. 조회 실패를 분리하는 후속 수정은 로컬 계약 테스트만 완료했다. 추가 원격 실행은 사용자 예외 승인 후 가능하며, 실제 Watch 런타임과 앱 테스트의 정상 실행까지 확인해야 원격 단위 검증 완료로 처리한다.

## Prevention

`pipefail`을 사용하는 조회 파이프라인에서는 생산자가 종료하기 전에 소비자가 출력을 닫는 `grep -q` 등의 사용을 검토한다. 목록 회귀 테스트는 작은 단일 행뿐 아니라 일치 행 뒤에 파이프 버퍼를 초과하는 출력이 남는 경우를 포함한다.

## Lessons Learned

일치 행을 찾았다는 사실과 생산자 명령의 성공은 별개다. 실제로 존재하는 기기를 다시 생성하거나 서비스 전체를 재시작하기 전에 목록 판정 파이프라인의 종료 상태를 확인한다.
