---
tags: [xctest, ui-testing, timeout, worktree, simulator, concurrency]
category: testing
date: 2026-09-27
status: implemented
severity: important
related_files:
  - scripts/lib/simulator-worktree.sh
  - scripts/lib/simulator-test-lock.py
  - scripts/test-ui.sh
  - scripts/test-unit.sh
  - scripts/test-watch-ui.sh
  - DUNEUITests/Full/ActivityExercisePickerRegressionTests.swift
related_solutions:
  - 2026-09-27-codex-worktree-simulator-isolation
  - 2026-03-29-ui-test-force-kill-cascade-prevention
---

# 동시 시뮬레이터 실행으로 발생한 운동 선택 테스트 타임아웃

## Problem

`testFullPickerSupportsFilterSelectorsAndSelectionFromTemplateForm`이 180초 제한을 초과했다. 최초 trace에서는 Recent Workouts의 See All 탭 뒤 app idle 대기가 보였고, 다른 격리 실행에서는 Exercise/템플릿 폼/picker까지 진행한 뒤 제한을 초과했다. 호스트 load average가 수백까지 올라 여러 테스트 실행이 서로 영향을 주고 있었다.

다른 Health 작업과 순서를 조정한 단독 실행에서는 **테스트·앱 코드와 `executionTimeAllowance = 180`을 바꾸지 않고 73.442초에 통과**했다. 증거 로그는 `/private/tmp/dune-9ef0-picker-solo.log`다. 따라서 제한 숫자를 늘리는 변경은 철회하고 180초를 유지한다.

## Solution

- 같은 `Health` basename을 갖는 워크트리가 같은 시뮬레이터를 재사용하지 않도록 전체 경로 hash 기반 기기 키 수정(319790ed/3320d05e)을 재사용한다.
- 동일 Git 저장소의 표준 iOS/watchOS 단위·UI 테스트 실행기를 공유 OS 잠금으로 직렬 실행한다. 부팅과 프로젝트 생성 전에 잠금을 획득하여 한 작업이 끝나면 다음 작업이 진행하도록 한다.
- 운동 목록 See All은 `scrollToHittableElementIfNeeded`로 보일 때까지 스크롤하고 실제 `app.buttons[...]`를 탭한다. XCTest의 암묵적인 자동 스크롤 의존을 줄이며 기존 assertion은 유지한다.
- 앱 동작이나 컨투어 모션, 테스트 제한 시간은 변경하지 않는다.

## Validation

- 워크트리 격리 Python 회귀 테스트 4개 통과.
- 테스트 Swift 구문 검사 및 `git diff --check` 통과.
- See All 테스트 변경의 별도 코드 리뷰: actionable findings 없음.
- 공유 잠금 subprocess 회귀 테스트 5개 통과(Python 3.9): 워크트리 상호 배제, shell 재진입/자식 실행 중 잠금, 오류·중단 후 해제, 인자·종료 코드 보존, 잘못된 저장소/FD 거부.
- pre-commit DUNEUITests build-for-testing 통과.
- 수정 후 원래 실패한 picker UI 테스트 **1개, 실패 0개, 71.770초 통과**. `executionTimeAllowance = 180` 유지.
  - 명령: `DAILVE_IOS_SIMULATOR="Contour Clean f7c6" DAILVE_IOS_OS=27.0 scripts/test-ui.sh --no-regen --only-testing DUNEUITests/ActivityExercisePickerRegressionTests/testFullPickerSupportsFilterSelectorsAndSelectionFromTemplateForm --log-file /tmp/contour-timeout-fixed.log`
  - 로그: `/private/tmp/contour-timeout-fixed.log`; xcodebuild exit 0.
  - 전체 UI suite 재검증 결과를 의미하지 않는다.

## Prevention

- 같은 저장소의 시뮬레이터 검증은 표준 실행기를 사용한다. 직접 `xcodebuild` 실행이나 다른 저장소의 테스트까지 이 잠금이 제어하지는 않는다.
- 타임아웃 발생 시 assertion 실패, app idle 대기, 호스트 부하를 구분하고 단독 재현과 비교한다.
- 개별 제한 확대만으로 환경 충돌을 숨기지 않는다.
- 기존 버튼 우선 탐색 규칙을 재사용하며 `.claude/rules` 수정은 하지 않는다.

## Lessons Learned

기기 이름 분리는 데이터 충돌을 막고 실행 직렬화는 호스트 자원 경합을 줄인다. 두 문제를 나누어 검증해야 앱 로직 문제로 오판하지 않는다.
