---
tags: [unit-test, watchos, swift-testing, ci, coverage]
date: 2026-03-02
category: plan
status: implemented
---

# 유닛 테스트 전면 강화 (Apple Watch 포함)

## Context

현재 `DUNETests`는 폭넓게 존재하지만, watchOS 앱(`DUNEWatch`)은 유닛 테스트 타깃이 없어 핵심 로직 회귀가 PR 단계에서 자동 차단되지 않는다.  
요청 기준은 다음과 같다:

- 1순위 목표: **릴리즈 안정성**
- Watch 포함 단위 테스트 강화 기준: **100% 목표**
- PR 게이트: **필수**
- 우선순위: iOS/Watch **동시 강화**
- 구현 범위: **테스트 추가 중심** (기능 리팩터링 제외)
- 제외 범위: HealthKit 실연동/실기기 의존 시나리오

## Requirements

### Functional

- watchOS 유닛 테스트 타깃(`DUNEWatchTests`)을 추가한다.
- Watch 핵심 순수 로직(RecentExerciseTracker, WatchExerciseHelpers, WatchExerciseInfo Hashable)을 단위 테스트로 보강한다.
- CI Unit Test 파이프라인에서 iOS + Watch 유닛 테스트를 모두 필수 실행한다.
- 로컬 실행 스크립트도 동일 기준(iOS + Watch)으로 통합한다.

### Non-functional

- 실기기/실연동 의존 테스트는 제외하고 시뮬레이터 기반으로 통과 가능해야 한다.
- 테스트는 flaky 없이 반복 실행 가능해야 한다.
- 기존 앱 로직 변경은 최소화하고, 테스트 인프라/테스트 코드 중심으로 변경한다.

## Approach

`DUNEWatchTests` 타깃을 XcodeGen(`DUNE/project.yml`)에 추가하고, Watch 순수 로직을 Swift Testing으로 검증한다.  
동시에 `scripts/test-unit.sh`와 `.github/workflows/test-unit.yml`을 확장해 PR 단계에서 iOS + Watch 유닛 테스트를 강제한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| DUNETests만 확장 (공유 모델만 테스트) | 빠름, 설정 변경 적음 | `DUNEWatch` 전용 로직 미검증 | 기각 |
| `DUNEWatchTests` 타깃 신설 + CI 필수화 | Watch 로직 직접 검증, 안정성 향상 | 프로젝트/스크립트 변경 필요 | 채택 |
| 실기기 연동 테스트까지 포함 | 현실 시나리오 검증 강함 | 자동화 비용 높고 flaky 위험 | 범위 제외 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/project.yml` | Modify | `DUNEWatchTests` 타깃/스킴 추가, 통합 테스트 스킴 반영 |
| `DUNEWatchTests/RecentExerciseTrackerTests.swift` | Add | canonicalization, usage/popular, latest set fallback 테스트 |
| `DUNEWatchTests/WatchExerciseHelpersTests.swift` | Add | subtitle, dedup, defaults, snapshot 테스트 |
| `DUNEWatchTests/WatchExerciseInfoHashableTests.swift` | Add | id 기반 Hashable/Equatable 보장 테스트 |
| `scripts/test-unit.sh` | Modify | iOS + Watch 유닛 테스트 순차 실행 |
| `.github/workflows/test-unit.yml` | Modify | Watch 테스트 파일/타깃 변경 시 Unit workflow 트리거 |
| `scripts/hooks/pre-commit.sh` | Modify | `DUNEWatchTests` 변경 시 빌드 체크 트리거 |

## Implementation Steps

### Step 1: Watch Unit Test 타깃 추가

- **Files**: `DUNE/project.yml`
- **Changes**:
  - `DUNEWatchTests` (`bundle.unit-test`, `platform: watchOS`, dependency: `DUNEWatch`) 추가
  - `DUNEWatchTests` 전용 scheme 추가
  - 통합 `DUNE` scheme 테스트 대상에 `DUNEWatchTests` 포함
- **Verification**: `scripts/build-ios.sh` 성공, 생성된 `.xcodeproj`에서 `DUNEWatchTests` 확인

### Step 2: Watch 핵심 로직 테스트 추가

- **Files**: `DUNEWatchTests/*.swift`
- **Changes**:
  - `RecentExerciseTracker` 저장/정렬/정규화/fallback 로직 테스트
  - `WatchExerciseHelpers` 순수 함수 테스트
  - `WatchExerciseInfo` id 기반 Hashable semantics 테스트
- **Verification**: `xcodebuild test -scheme DUNEWatchTests -only-testing DUNEWatchTests` 통과

### Step 3: CI/로컬 Unit 게이트 강화

- **Files**: `scripts/test-unit.sh`, `.github/workflows/test-unit.yml`, `scripts/hooks/pre-commit.sh`
- **Changes**:
  - unit script를 iOS + Watch 테스트 모두 실행하도록 확장
  - workflow path trigger에 `DUNEWatch/**`, `DUNEWatchTests/**` 반영
  - pre-commit build trigger path에 `DUNEWatchTests` 반영
- **Verification**: `scripts/test-unit.sh` 실행 시 두 테스트 세트 순차 실행 및 로그 출력

### Step 4: 최종 검증/문서화

- **Files**: `docs/solutions/testing/2026-03-02-watch-unit-test-hardening.md`
- **Changes**: 변경 배경, 해결 방법, 예방책 문서화
- **Verification**: 문서 frontmatter/카테고리/태그 규칙 충족

## Edge Cases

| Case | Handling |
|------|----------|
| UserDefaults 기반 테스트 상태 오염 | 테스트마다 저장 키 초기화, serialized suite 적용 |
| watchOS 시뮬레이터 이름/OS 불일치 | 환경변수로 destination override 가능하게 유지 |
| HealthKit 실연동 의존 로직 | 단위 테스트 범위에서 제외하고 순수 로직만 검증 |
| canonical ID 중복 대표 선택 | usage count → recency → name 순 tie-break 검증 |

## Testing Strategy

- Unit tests (iOS): `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNETests`
- Unit tests (watchOS): `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNEWatchTests -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm),OS=26.2' -only-testing DUNEWatchTests`
- Integration/Manual: 실기기 의존 시나리오는 이번 범위에서 제외

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| watchOS 시뮬레이터 환경 차이로 CI 변동 | Medium | Medium | destination env override + 로그 artifact 확보 |
| 프로젝트 생성물(`.xcodeproj`) diff 증가 | Medium | Low | `scripts/lib/regen-project.sh` 경로로만 재생성 |
| UserDefaults 기반 테스트 flaky | Low | Medium | serialized + key cleanup으로 결정성 확보 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 iOS 테스트 인프라를 재사용하며, 이번 변경은 테스트 코드/인프라 중심이라 제품 런타임 리스크가 낮다.
