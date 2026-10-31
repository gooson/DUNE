---
tags: [ci, github-actions, unit-tests, simulator, watchos, isolation]
date: 2026-10-31
category: testing
status: implemented
related_files:
  - .github/workflows/test-unit.yml
  - scripts/test-unit.sh
  - scripts/tests/test_unit_test_runner.py
  - DUNE/project.yml
  - DUNE/DUNE.xcodeproj/project.pbxproj
related_solutions:
  - docs/solutions/testing/2026-10-31-simulator-preflight-pipefail.md
---

# CI 유닛 테스트의 iOS·Watch 실행 환경 분리

## Problem

[Unit Tests 실행 41148350186](https://github.com/gooson/DUNE/actions/runs/41148350186)은 컴파일이나 테스트 실행 전에 실패했다. iOS 시뮬레이터가 부팅된 뒤 Watch 사전 `simctl list devices` 조회가 30초 제한으로 종료했고, 실행기는 `device lookup failed (exit 124)`를 보고했다. 같은 커밋의 [Build iOS](https://github.com/gooson/DUNE/actions/runs/41148350258)는 통과했다.

기존 실행기는 iOS·Watch 기기를 모두 준비하고 부팅한 뒤 첫 iOS 테스트를 실행했다. 따라서 Watch 준비 실패 하나가 두 플랫폼의 테스트와 테스트 로그 생성을 모두 막았다. 이전 실행에서는 iOS 부팅 뒤 Watch 런타임이 사라진 기록도 있다. 런타임 소실과 조회 지연의 호스트 내부 원인은 로그만으로 확정할 수 없다.

## Solution

- CI matrix를 `ios`, `watch`로 나눠 각 작업이 별도 runner에서 `--ios-only`, `--watch-only`를 실행한다. 한 작업의 실패로 다른 플랫폼을 취소하지 않도록 `fail-fast: false`를 사용한다.
- 두 플랫폼의 전체 unit suite와 기존 부팅 제한·재시도 설정은 유지한다. artifact 이름은 플랫폼별로 구분한다.
- 로컬 기본 실행도 각 suite 직전에 해당 플랫폼의 destination을 결정하고 부팅한다. Watch 준비가 실패해도 먼저 완료한 iOS 테스트 결과와 로그가 남는다.
- `DUNEWatchTests`의 `TEST_TARGET_NAME`을 제거한다. [XcodeGen 생성 코드](https://github.com/yonaskolb/XcodeGen/blob/master/Sources/XcodeGenKit/PBXProjGenerator.swift)는 이 설정을 UI test bundle에만 부여하고 unit test bundle에는 `TEST_HOST`를 생성한다. 생성된 Watch `TEST_HOST`와 `BUNDLE_LOADER`, 앱 타입, scheme은 유지한다.
- CI runner의 전체 stdout·stderr를 별도 로그에 저장하고 `include-hidden-files: true`로 `.xcodebuild` 로그를 업로드한다. 명시적 `shell: bash`의 `pipefail`로 `tee` 뒤에서도 테스트 실패 코드를 유지한다.

## Verification

가짜 `simctl`·`xcodebuild`를 사용하는 subprocess 계약 테스트로 부팅과 테스트의 순서를 검사한다. 수정 전에는 두 기기를 먼저 부팅하는 순서가 재현됐다.

- iOS 부팅 → iOS 테스트 → Watch 부팅 → Watch 테스트 순서
- Watch 사전 조회 오류의 실패 상태 유지와 완료된 iOS 테스트 로그 보존
- `--ios-only`·`--watch-only`가 선택하지 않은 기기를 부팅하지 않음
- 기존 selector 라우팅, dry-run, 로그 분리, 테스트 수 검증 유지

`python3 -B -m unittest scripts.tests.test_unit_test_runner`의 19개 계약 테스트, shell 구문 검사, workflow YAML 파싱 및 matrix 명령의 dry-run이 통과했다. 로그 보존 pipeline도 가짜 실패 실행기를 사용해 두 플랫폼의 stderr 저장과 종료 코드 65 보존을 확인했다.

PR #877의 [첫 Watch 실행](https://github.com/gooson/DUNE/actions/runs/41160626407/job/124417160160)은 이전 부팅 실패 구간을 지나 Watch 앱과 테스트 bundle의 빌드까지 완료했다. 이후 `Cannot test target DUNEWatchTests on iPhone 17` 오류로 실제 테스트가 시작되지 않아 unit target의 UI test용 설정을 조사했다. `TEST_TARGET_NAME` 제거 후 로컬 Xcode 27.2에서 아래 표준 실행기로 전용 Watch 시뮬레이터의 테스트 14개가 통과했다.

```sh
python3 -B scripts/lib/command-deadline.py --seconds 1200 -- \
  scripts/test-unit.sh --watch-only \
  --only-testing DUNEWatchTests/WatchRPEEstimatorTests \
  --log-file .xcodebuild/ship-watch-focused.log
```

이 로컬 검증은 해당 Watch suite와 타깃 컴파일의 성공 근거다. 전체 suite의 원격 통과 여부는 [PR #877 검사](https://github.com/gooson/DUNE/pull/877/checks)에서 별도로 확인한다.

## Prevention

플랫폼별 테스트의 준비 단계를 서로 의존시키지 않는다. 테스트 시작 전 실패는 앱 테스트 실패와 구분하고, runner 로그의 실제 실패 명령과 종료 코드를 근거로 조사한다. 부팅 제한 완화나 테스트 생략으로 CI 실패를 숨기지 않는다.

Watch 테스트를 추가할 때 컴파일 성공만으로 실행 가능하다고 판단하지 않는다. unit target에는 UI test 전용 설정을 넣지 않고, 실제 Watch destination에서 양수의 테스트 실행 수와 성공 종료를 함께 확인한다.
