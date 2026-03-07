---
topic: Pre-commit Build Fast Gate
date: 2026-03-07
status: approved
confidence: high
related_solutions:
  - docs/solutions/general/2026-02-23-activity-recent-workouts-style-and-ios-build-guard.md
  - docs/solutions/testing/2026-03-02-watch-unit-test-hardening.md
  - docs/solutions/testing/2026-03-04-pr-fast-gate-and-nightly-regression-split.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-agentic-coding-validation-time-reduction.md
---

# Implementation Plan: Pre-commit Build Fast Gate

## Context

현재 `scripts/hooks/pre-commit.sh` 는 Swift/Xcode 관련 staged 변경이 있으면 항상 `scripts/build-ios.sh --no-regen` 을 실행한다. 동시에 훅 시작 시 `.deriveddata` 와 `.xcodebuild` 를 삭제해 매 커밋마다 cold build 를 강제하고 있어, 빠른 검증 게이트라는 원래 목적과 반대로 프리커밋이 가장 큰 허들이 되고 있다.

## Requirements

### Functional

- pre-commit 이 staged 변경 유형에 따라 필요한 최소 compile gate 만 실행해야 한다.
- `DUNE/project.yml` 변경 시에는 regen 이 포함된 검증 경로를 유지해야 한다.
- 앱/공유 소스 변경은 기존 `scripts/build-ios.sh` 단일 진입점 정책을 유지해야 한다.
- 테스트 타깃 전용 변경은 전체 앱 빌드 대신 해당 타깃 compile 검증으로 대체해야 한다.

### Non-functional

- 반복 커밋에서 incremental build cache 를 재사용할 수 있어야 한다.
- 기존 secret/TODO/.env 검증은 유지해야 한다.
- 훅 로직은 bash 단일 파일 기준으로 읽기 쉬워야 한다.

## Approach

pre-commit 을 path-aware fast gate 로 바꾼다.

- artifact cleanup 의 자동 실행을 제거해 `.deriveddata` 를 보존한다.
- staged 파일 목록을 한 번 수집하고, 변경 유형에 따라 검증 명령을 분기한다.
- 앱/공유 소스 또는 project spec 변경은 `scripts/build-ios.sh` 를 계속 사용하되, `project.yml` 변경일 때만 regen 을 허용한다.
- `DUNETests`, `DUNEWatchTests`, `DUNEUITests`, `DUNEWatchUITests` 전용 변경은 각 스킴별 `xcodebuild build-for-testing` compile gate 로 축소한다.
- 공통 compile gate 는 별도 스크립트로 분리해 pre-commit 외에도 재사용 가능하게 만든다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| pre-commit build 완전 제거 | 가장 빠름 | 회귀를 커밋 이후로 미룸 | 기각 |
| 기존 훅 유지 + skip env 사용 권장 | 구현 단순 | 기본 UX 개선이 없음, 우회에 의존 | 기각 |
| path-aware fast gate + cache 보존 | 속도와 안전성 균형 | 분기 로직 추가 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/hooks/pre-commit.sh` | modify | staged path 분류, cleanup 제거, fast gate 분기 |
| `scripts/build-target.sh` | add | 스킴별 build-for-testing / build 공통 실행기 추가 |
| `docs/solutions/general/2026-03-07-precommit-build-fast-gate.md` | add | 해결책 문서화 |

## Implementation Steps

### Step 1: Fast gate command 도입

- **Files**: `scripts/build-target.sh`
- **Changes**: regen-project 공용 로직을 재사용하면서 스킴/플랫폼별 compile 검증을 수행하는 스크립트 추가
- **Verification**: help/usage 와 대표 스킴 1개 이상 실행 확인

### Step 2: Pre-commit path routing

- **Files**: `scripts/hooks/pre-commit.sh`
- **Changes**: staged 목록 캐싱, 변경 카테고리 분류, app/project 변경 시 full build, test-only 변경 시 targeted compile
- **Verification**: staged 경로 조합별로 실행 명령이 기대대로 선택되는지 확인

### Step 3: Validation

- **Files**: `scripts/hooks/pre-commit.sh`, `scripts/build-target.sh`
- **Changes**: 실제 빌드 실행으로 스크립트 오류 제거
- **Verification**: full build 1회, test-only targeted compile 1회, pre-commit dry-run 성격 검증 1회

## Edge Cases

| Case | Handling |
|------|----------|
| `project.yml` 과 테스트 파일이 함께 변경됨 | regen 포함 full build 우선 |
| watch UI test 만 변경됨 | `DUNEWatchUITests` build-for-testing 실행 |
| shared source 변경으로 여러 타깃이 영향받음 | path 분류를 단순화해 full build 로 승격 |
| staged 변경이 없는 상태에서 hook 수동 실행 | build 단계 없이 기본 검증만 통과 |

## Testing Strategy

- Unit tests: 없음, bash 스크립트 변경은 실제 명령 실행으로 검증
- Integration tests: `scripts/build-ios.sh --no-regen`, `scripts/build-target.sh --scheme ...`
- Manual verification: staged test-only 변경을 만들어 pre-commit 이 targeted gate 를 선택하는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| path 분류 누락으로 필요한 full build 가 빠짐 | medium | high | app/shared/project 관련 경로는 보수적으로 full build 로 묶음 |
| `build-for-testing` 대상 destination 설정 불일치 | medium | medium | generic simulator destination 사용 |
| cache 보존으로 stale artifact 문제가 남음 | low | medium | 수동 cleanup 스크립트는 유지하고, build 실패 시 로그 경로를 출력 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 현재 병목의 직접 원인이 훅 내부에 명확히 있고, 변경은 hook/build script 범위에 국한되며 기존 단일 빌드 정책도 유지할 수 있다.
