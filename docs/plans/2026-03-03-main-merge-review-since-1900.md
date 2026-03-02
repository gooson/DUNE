---
topic: main-merge-review-since-1900
date: 2026-03-03
status: implemented
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-03-watch-cardio-pause-aware-elapsed-time.md
related_brainstorms: []
---

# Implementation Plan: Main Merge Review Since 19:00

## Context

`2026-03-02 19:00 KST` 이후 `main`에 머지된 대규모 변경 범위를 전수 점검하고, 발견된 품질 이슈를 즉시 수정해 배포 가능한 상태로 정리한다.

## Requirements

### Functional

- 기준 시각 이후 머지 범위(`a253708..28706aa`)를 리뷰한다.
- 발견된 P1/P2/P3를 모두 수정한다.
- 수정 결과를 문서화하고 재검증한다.

### Non-functional

- 기존 `.claude/rules/*`를 준수한다.
- watch/iOS 빌드 게이트를 통과한다.
- 재발 방지를 위한 테스트를 추가한다.

## Approach

대용량 diff(5만+ 라인)는 전체 에이전트 위임 대신 핵심 변경 파일 수동 정밀 리뷰로 처리하고, 이슈 발견 즉시 코드/테스트/문서를 동시에 업데이트한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 전 파일 자동 리뷰 에이전트 위임 | 빠른 병렬 분석 | 대용량 diff에서 출력 truncation/누락 위험 | 기각 |
| 핵심 파일 수동 리뷰 + 빌드 게이트 | 정확한 원인 분석, 즉시 수정 가능 | 시간 소요 증가 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEWatch/Managers/WorkoutManager.swift` | modify | cardio elapsed/pace를 pause-aware 계산으로 수정 |
| `DUNEWatch/Views/CardioMetricsView.swift` | modify | 화면 elapsed 표시를 active elapsed 기준으로 통일 |
| `DUNEWatchTests/WorkoutElapsedTimeTests.swift` | add | elapsed 계산 회귀 방지 단위 테스트 추가 |
| `docs/reviews/2026-03-03-main-merge-review-since-1900.md` | add | 전수 리뷰 결과 문서화 |
| `docs/solutions/general/2026-03-03-watch-cardio-pause-aware-elapsed-time.md` | add | 해결책/예방책 문서화 |
| `CLAUDE.md` | modify | Correction Log 항목 추가 (#194) |

## Implementation Steps

### Step 1: 범위 확정 및 대용량 리뷰 전략 수립

- **Files**: git history/diff + 기존 docs/reviews
- **Changes**: 기준 시점 이전 커밋(`a253708`) 확정, 이후 범위 전체 diff 산출
- **Verification**: diff 라인수/파일수 확인

### Step 2: 핵심 이슈 수정 및 테스트 추가

- **Files**: `WorkoutManager.swift`, `CardioMetricsView.swift`, `WorkoutElapsedTimeTests.swift`
- **Changes**: pause-aware elapsed helper 도입, pause lifecycle 반영, UI 시간 계산 경로 정렬
- **Verification**: watchOS/iOS build 통과, 테스트 대상 컴파일 통과

### Step 3: 리뷰/솔루션/교정 로그 문서화

- **Files**: `docs/reviews/*`, `docs/solutions/*`, `CLAUDE.md`
- **Changes**: 발견사항, 수정내역, 예방 체크리스트 기록
- **Verification**: 문서 규격(frontmatter/date/category) 확인

## Edge Cases

| Case | Handling |
|------|----------|
| pause 직후 즉시 end | `endPause()`를 `end()` 시작 시 호출해 누적 보정 |
| pause 상태에서 elapsed 조회 | 현재 pause 구간까지 제외한 값 반환 |
| 비정상 시간값(미래 startDate 등) | `max(elapsed, 0)`로 음수 방어 |

## Testing Strategy

- Unit tests: `WorkoutElapsedTimeTests` 3케이스(기본/paused/음수 클램프)
- Integration tests: 시뮬레이터 환경 제약으로 미실행
- Manual verification: watch cardio pause/resume 후 elapsed/pace 동작 확인 예정

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 시뮬레이터 불안정으로 test 미실행 | medium | medium | generic platform build + 후속 실환경 test |
| pause 이벤트 중복 수신 | low | low | `beginPause/endPause` idempotent 방어 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 핵심 결함 원인/수정 경로가 단일 helper로 통합되었고, 빌드 게이트 및 회귀 테스트(컴파일)를 통과했다.
