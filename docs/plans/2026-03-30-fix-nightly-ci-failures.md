---
topic: fix-nightly-ci-failures
date: 2026-03-30
status: draft
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-08-ui-smoke-toolbar-tap-stability.md
related_brainstorms: []
---

# Implementation Plan: Fix Nightly CI Failures

## Context

GitHub Actions nightly run #23692748227 (2026-03-28) 에서 4개 job 중 3개 실패:
1. **nightly-watch-unit-tests** — `CompletedSetData` init에 `duration` 파라미터 누락으로 컴파일 에러
2. **nightly-ios-unit-tests** — 빌드 성공 후 시뮬레이터 부팅 hang → 45분 timeout
3. **nightly-ios-ui-tests** — 개별 테스트 2분 timeout 초과 → terminate 실패 → 연쇄 실패 → 90분 timeout

최근 5회 nightly 전부 실패. Watch UI test만 일관 통과.

## Requirements

### Functional
- Watch unit test가 컴파일되어야 함
- iOS unit test가 시뮬레이터 부팅 실패 시 45분 hang 대신 fail-fast
- iOS UI test가 개별 테스트 timeout에서 연쇄 실패 방지

### Non-functional
- 기존 로컬 개발 워크플로우에 영향 없음
- CI 비용 감소 (hang으로 인한 runner 낭비 방지)

## Approach

3개 독립 수정을 하나의 PR로 통합.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 시뮬레이터 pre-boot 추가 | fail-fast, 명확한 에러 메시지 | 부팅 시간 약간 추가 | **채택** |
| xcodebuild에 -timeout 옵션 | 간단 | xcodebuild에 해당 옵션 없음 | 불가 |
| CI workflow timeout 줄이기 | 구현 쉬움 | 근본 원인 미해결, 여전히 낭비 | 보조 수단만 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEWatchTests/WatchRPEEstimatorTests.swift` | Fix | `makeSet` 헬퍼에 `duration: nil` 추가 |
| `scripts/test-unit.sh` | Enhancement | 시뮬레이터 pre-boot + 120s boot wait 추가 |
| `scripts/test-ui.sh` | Enhancement | boot wait timeout 추가, test time allowance 증가 |
| `scripts/test-watch-ui.sh` | Enhancement | boot wait timeout 추가 (일관성) |

## Implementation Steps

### Step 1: Watch unit test 컴파일 에러 수정

- **Files**: `DUNEWatchTests/WatchRPEEstimatorTests.swift`
- **Changes**: `makeSet` 헬퍼의 `CompletedSetData` init 호출에 `duration: nil` 추가
- **Verification**: `xcodebuild build-for-testing -scheme DUNEWatchTests` 성공

### Step 2: test-unit.sh에 시뮬레이터 pre-boot 추가

- **Files**: `scripts/test-unit.sh`
- **Changes**: `preboot_simulator` 함수 추가 — UDID 추출, `simctl boot`, Booted 상태 대기 (120s timeout)
- **Verification**: `scripts/test-unit.sh --watch-only` 로컬 실행 성공

### Step 3: test-ui.sh boot wait + time allowance 증가

- **Files**: `scripts/test-ui.sh`
- **Changes**: boot 후 Booted 상태 대기 추가, `default-test-execution-time-allowance` 120→300, `maximum` 300→600
- **Verification**: `scripts/test-ui.sh --smoke --no-regen` 실행 확인

### Step 4: test-watch-ui.sh boot wait 추가

- **Files**: `scripts/test-watch-ui.sh`
- **Changes**: boot 후 Booted 상태 대기 추가 (일관성)
- **Verification**: 스크립트 구문 오류 없음 (bash -n)

## Edge Cases

| Case | Handling |
|------|---------|
| 시뮬레이터 UDID 추출 실패 | Warning 출력 후 xcodebuild에 위임 (기존 동작) |
| 시뮬레이터가 이미 Booted | `simctl boot` 에러 무시 (|| true), 즉시 통과 |
| 120s 내 부팅 실패 | exit 1로 fail-fast (45분 hang 방지) |

## Testing Strategy

- Watch unit test: `xcodebuild build-for-testing -scheme DUNEWatchTests` 컴파일 확인
- iOS build: `scripts/build-ios.sh` 성공 확인
- Script 구문: `bash -n` 으로 각 스크립트 검증
- CI 실행은 PR merge 후 nightly에서 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| pre-boot이 CI에서도 hang | Low | Medium | 120s timeout으로 fail-fast |
| time allowance 증가로 느린 테스트 미발견 | Low | Low | 300s는 여전히 합리적 상한 |
| 로컬 개발에 영향 | Very Low | Low | pre-boot은 기존 동작과 동일 (이미 booted면 skip) |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 변경이 단순하고 격리됨. test infrastructure만 수정하고 앱 코드는 test helper만 수정.
