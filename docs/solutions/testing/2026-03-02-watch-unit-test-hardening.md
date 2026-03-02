---
tags: [watchos, unit-test, swift-testing, ci, regression, xcodegen]
date: 2026-03-02
category: solution
status: implemented
---

# Solution: Watch 포함 Unit Test 게이트 강화

## Problem

- 기존 Unit Test 자동화는 iOS `DUNETests` 중심이라 watchOS 앱 로직 회귀를 PR 단계에서 강제 차단하지 못했다.
- `DUNEWatch` 핵심 순수 로직(`RecentExerciseTracker`, `WatchExerciseHelpers`)에 대한 전용 유닛 테스트 타깃이 없었다.
- Unit workflow가 `DUNEWatch`/`DUNEWatchTests` 변경을 트리거하지 않아 Watch 변경이 테스트 게이트를 우회할 수 있었다.

## Solution

### 1. Watch Unit Test 타깃 추가

- `DUNE/project.yml`에 `DUNEWatchTests` (`bundle.unit-test`, `platform: watchOS`) 타깃/스킴을 추가했다.
- `DUNE` 통합 스킴에도 `DUNEWatchTests`를 포함해 전체 테스트 매트릭스에 Watch를 편입했다.
- 생성 산출물:
  - `DUNE/DUNE.xcodeproj/project.pbxproj`
  - `DUNE/DUNE.xcodeproj/xcshareddata/xcschemes/DUNEWatchTests.xcscheme`
  - 관련 기존 스킴 업데이트

### 2. Watch 순수 로직 유닛 테스트 추가

- `DUNEWatchTests/RecentExerciseTrackerTests.swift`
  - canonical ID 정규화
  - sorted/popular 우선순위
  - latest set exact/canonical fallback
- `DUNEWatchTests/WatchExerciseHelpersTests.swift`
  - subtitle 포맷/범위 검증
  - canonical dedup
  - default 해석 및 snapshot 생성
- `DUNEWatchTests/WatchExerciseInfoHashableTests.swift`
  - id 기반 Hashable/Equatable semantics 검증

### 3. Unit 게이트를 iOS + Watch 필수 실행으로 확장

- `scripts/test-unit.sh`를 iOS/Watch 순차 실행 구조로 확장했다.
- simulator 이름이 환경과 다를 때를 대비해 destination 자동 fallback 로직을 추가했다.
- `.github/workflows/test-unit.yml`에 `DUNEWatch/**`, `DUNEWatchTests/**` path trigger를 추가했다.
- `scripts/hooks/pre-commit.sh` 빌드 트리거에 `DUNEWatchTests/`를 포함했다.

## Verification

- `scripts/build-ios.sh` 성공 (`BUILD SUCCEEDED`)
- `xcodebuild build-for-testing -scheme DUNETests -destination 'generic/platform=iOS Simulator'` 성공 (`TEST BUILD SUCCEEDED`)
- `xcodebuild build-for-testing -scheme DUNEWatchTests -destination 'generic/platform=watchOS Simulator'` 성공 (`TEST BUILD SUCCEEDED`)
- `scripts/test-unit.sh`의 런타임 테스트는 로컬 환경의 CoreSimulator 서비스 오류(`simdiskimaged`/connection invalid)로 실행 불가했으며, 컴파일 단계 검증으로 대체했다.

## Prevention

- Watch 로직 변경 시 `DUNEWatchTests` 동반 업데이트를 기본 규칙으로 유지한다.
- Unit workflow trigger에서 `DUNEWatch`/`DUNEWatchTests` 경로를 지속 포함한다.
- 시뮬레이터 이름 고정값 의존을 줄이기 위해 destination fallback 패턴을 테스트 스크립트 표준으로 사용한다.

## Files

| File | Change |
|------|--------|
| `DUNE/project.yml` | `DUNEWatchTests` 타깃/스킴 및 통합 스킴 테스트 대상 추가 |
| `DUNEWatchTests/*.swift` | Watch 유닛 테스트 신규 추가 |
| `scripts/test-unit.sh` | iOS + Watch 순차 실행 + destination fallback |
| `.github/workflows/test-unit.yml` | Watch 관련 path trigger 및 로그 패턴 확장 |
| `scripts/hooks/pre-commit.sh` | `DUNEWatchTests/` 빌드 트리거 추가 |
