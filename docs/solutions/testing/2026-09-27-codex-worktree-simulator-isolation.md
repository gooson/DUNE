---
tags: [codex, worktree, simulator, ui-testing, isolation, basename-collision]
category: testing
status: implemented
date: 2026-09-27
severity: important
related_files:
  - scripts/lib/simulator-worktree.sh
  - scripts/tests/test-simulator-worktree.py
related_solutions: []
---

# Solution: 동일 basename의 Codex 워크트리 시뮬레이터 격리

## Problem

UI 회귀 테스트에서 화면 전환 확인 실패와 XCTest 응답 지연이 발생했다. 재시도에서는 `SBMainWorkspace: Busy / Application failed preflight checks`로 테스트 러너 실행도 거부됐다.

### Root Cause

격리 스크립트가 `basename "$git_toplevel"`만 기기 이름으로 사용했다. Codex의 `…/9ef0/Health`, `…/b4d7/Health`는 모두 `Health`여서 같은 `iPhone 18 Pro-wt-Health`를 재사용할 수 있었다. `--cleanup-current`도 같은 이름을 대상으로 했다.

이 이름 충돌은 재현 테스트로 확인된 결함이다. 최초 운동 화면 assertion 실패의 단독 원인이라고 확정한 것은 아니다. 진단 당시 12 CPU 호스트의 load average가 560~750이었고 여러 시뮬레이터/빌드가 실행 중이어서 환경 지연도 함께 존재했다.

## Solution

- 워크트리 키를 `basename-SHA256(전체 경로)의 앞 12자리`로 변경한다.
- 기기 생성/검색과 현재 워크트리 정리가 같은 키를 사용한다.
- 기존 basename-only 기기는 다른 실행이 사용할 수 있으므로 자동 삭제하거나 종료하지 않는다.
- main checkout은 기존대로 원본 기기를 사용한다.
- 해시 계산 실패 시 공유 기기로 fallback하지 않고 오류를 반환한다.

## Validation

`python3 scripts/tests/test-simulator-worktree.py`: 동일 basename의 두 실제 Git worktree에서 서로 다른 안정적인 기기 이름, 정리 범위, main checkout passthrough, 해시 실패 시 안전한 중단을 검증하며 4개 테스트 통과.

`bash -n scripts/lib/simulator-worktree.sh` 통과. 실제 UI 재검증은 별도 로그로 기록한다. 미검증 UI 성공을 이 문서의 격리 테스트 결과와 혼동하지 않는다.

새 이름 `iPhone 18 Pro-wt-Health-a05933c9ea72`의 기기 생성과 부팅까지 확인했다. 이후 호스트 load average가 950까지 상승해 단일 UI 실행도 정상 시작을 확인하지 못한 채 중단했다. 따라서 UI 회귀 및 최초 화면 전환 assertion 해결 여부는 미검증이다. 코드 리뷰의 해시 실패 fallback 지적은 수정했고 재리뷰 추가 findings는 0건이다.

후속 격리 재검증(`Test-DUNEUITests-2026.09.27_02-37-54-+0900.xcresult`)에서는 기존 테스트와 앱 코드를 수정하지 않고 운동 화면 진입, 템플릿 폼 진입, picker 표시까지 진행했다. 결과 번들의 실패 원인은 `Test exceeded execution time allowance of 3 minutes`이며 1개 테스트 실패로 기록됐다. 최초 화면 assertion은 통과했지만 전체 테스트 성공은 아니다. 단독 실행 환경에서 남은 회귀 게이트를 확인해야 한다.

사용자 승인 후 다른 Health 테스트 실행을 중단하고 각 작업에 재시작 보류를 전달했다. 보류 직전 시작되어 뒤늦게 감지된 실행도 정리했다. 이후 `Test-DUNEUITests-2026.09.27_02-58-12-+0900.xcresult`에서 원래 picker 테스트가 **73.442초, 1개 통과 / 실패 0개**로 완료됐다. 테스트 코드와 180초 cap은 변경하지 않았다. 이 결과는 병렬 실행 부하의 영향을 뒷받침하며, 앱 네비게이션 수정이나 시간 제한 완화 없이 해당 재현을 통과한 증거다. 전체 UI suite 통과를 의미하지는 않는다.

## Prevention / Lessons Learned

동시 작업 리소스의 식별자로 마지막 폴더명만 사용하지 않는다. 격리 여부는 이름의 `wt` 표기가 아니라 각 작업의 실제 UDID와 전체 경로 키로 확인한다. UI timeout 진단에서는 앱 로직과 XCTest/호스트 지연을 구분한다. 기존 프로젝트 규칙 변경은 필요 없다.
