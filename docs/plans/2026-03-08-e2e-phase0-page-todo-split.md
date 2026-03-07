---
topic: E2E Phase 0 Page TODO Split
date: 2026-03-08
status: draft
confidence: high
related_solutions:
  - docs/solutions/testing/ui-test-infrastructure-design.md
  - docs/solutions/testing/2026-03-04-pr-fast-gate-and-nightly-regression-split.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: E2E Phase 0 Page TODO Split

## Context

`docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md`에는 전체 화면/전체 타겟 E2E 전략과 Phase 0-8 실행 플랜이 한 문서에 모여 있다. 사용자는 여기서 Phase 0를 실제 산출물로 전개하고, 모든 페이지를 TODO 문서로 분리해 이후 `/work`와 `/run`이 페이지 단위로 직접 이어질 수 있는 백로그를 원한다.

현재 `todos/`는 020번까지 사용 중이며, 대부분 기능 단위 단일 TODO로 유지되어 있다. 이번 작업은 E2E 회귀 표면을 페이지 단위로 쪼개되, must-have(`DUNE`, `DUNEWatch`)와 deferred(`DUNEVision`, `DUNEWidget`)를 우선순위로 구분해야 한다.

## Requirements

### Functional

- Phase 0 화면 인벤토리를 실제 TODO 문서 집합으로 분리한다.
- `DUNE` / `DUNEWatch`의 모든 navigable surface를 TODO로 만든다.
- `DUNEVision` / `DUNEWidget`의 모든 surface도 deferred TODO로 만든다.
- 각 TODO는 파일명, frontmatter, 우선순위, 상태가 `todo-conventions.md`를 따른다.
- 전체 TODO를 한눈에 볼 수 있는 index 문서를 추가한다.
- 원본 브레인스토밍 문서에서 분리된 TODO 문서 집합을 참조할 수 있게 한다.

### Non-functional

- 번호는 기존 `020` 다음부터 연속적으로 증가해야 한다.
- 파일명은 kebab-case로 유지한다.
- TODO 내용은 후속 구현자가 바로 `/plan`으로 이어갈 수 있게 충분히 구체적이어야 한다.
- diff는 문서 변경만 포함해야 하며 앱 코드 동작에는 영향을 주지 않아야 한다.

## Approach

Phase 0를 문서화 중심 작업으로 해석한다. 즉, 앱 코드 AXID 수정이나 launch argument 구현까지 들어가지 않고, 그 준비 단계인 inventory 정제와 TODO 분리 산출물을 만든다.

분리 단위는 "실제 내비게이션 가능한 surface"를 기본으로 한다. 동일한 공용 뷰라도 진입 컨텍스트가 다르면 다른 회귀 surface로 간주할 수 있지만, 이번 분리에서는 파일 기준 surface를 우선 사용해 과도한 TODO 폭증을 막는다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 루트 탭 단위 4~8개 TODO로만 분리 | 파일 수가 적고 관리가 쉬움 | "모든 페이지" 요구와 맞지 않고 후속 작업이 다시 커짐 | 기각 |
| navigable surface별 TODO 70+개 생성 | 페이지 단위 실행/추적이 쉬움 | 파일 수가 많아짐 | 채택 |
| 코드까지 수정해 Phase 0 완료 처리 | AXID 정리까지 한 번에 가능 | 이번 요청의 핵심은 TODO 분리이며 범위가 급격히 커짐 | 보류 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-08-e2e-phase0-page-todo-split.md` | add | 이번 작업의 구현 계획서 |
| `docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md` | update | 분리된 TODO 산출물 링크 및 Phase 0 진행 현황 반영 |
| `todos/021-ready-p2-e2e-phase0-page-backlog-index.md` | add | 전체 페이지 TODO 인덱스 |
| `todos/022-*.md` ~ `todos/095-*.md` | add | 페이지별 E2E 회귀 TODO 문서 |

## Implementation Steps

### Step 1: Surface 목록과 번호 정책 확정

- **Files**: `docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md`, `todos/`
- **Changes**:
  - 브레인스토밍 문서의 Product Surface Inventory를 기준으로 surface 목록을 고정한다.
  - 중복되는 공용 view는 가능한 한 단일 surface TODO로 합친다.
  - 번호는 021부터 연속 사용한다.
- **Verification**:
  - surface 수와 TODO 파일 수가 일치한다.
  - 번호 중복이 없다.

### Step 2: TODO index와 must-have surface TODO 생성

- **Files**: `todos/021-*.md` ~ `todos/083-*.md`
- **Changes**:
  - index 문서를 만들고 target/section별 TODO를 링크한다.
  - `DUNE`, `DUNEWatch` surface TODO를 `ready`, `p2`로 생성한다.
  - 각 TODO에 target, source file, entry point, regression scope, blockers를 기록한다.
- **Verification**:
  - `rg --files todos`로 새 파일이 모두 생성된다.
  - 각 파일 frontmatter가 규칙을 따른다.

### Step 3: deferred target TODO 생성

- **Files**: `todos/084-*.md` ~ `todos/095-*.md`
- **Changes**:
  - `DUNEVision`, `DUNEWidget` surface TODO를 `ready`, `p3`로 생성한다.
  - deferred 이유와 선행조건(AXID, harness, snapshot strategy 등)을 명시한다.
- **Verification**:
  - vision/widget 관련 surface가 index에 모두 나타난다.
  - must-have와 deferred priority가 구분된다.

### Step 4: Source 문서 연결 및 자체 검증

- **Files**: `docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md`
- **Changes**:
  - 분리된 TODO index 링크를 추가한다.
  - Phase 0 산출물이 문서 기준으로 생성되었음을 기록한다.
- **Verification**:
  - 브레인스토밍 문서만 읽어도 TODO backlog 진입점이 보인다.
  - `git diff --stat` 기준으로 변경 범위가 문서만 포함한다.

## Edge Cases

| Case | Handling |
|------|----------|
| 공용 view가 여러 탭에서 재사용됨 | 파일 기준 surface 1개로 만들고 본문에 multiple entry context를 적는다 |
| sheet와 detail의 경계가 애매함 | SwiftUI에서 독립 화면 전이를 만드는 타입은 별도 TODO로 분리한다 |
| 미래에 surface가 추가되어 번호가 뒤섞임 | 이번 범위는 021 이후 일괄 생성, 후속은 096부터 계속 증가 |
| vision/widget이 아직 자동화 불가 | `p3` deferred TODO로 만들고 선행조건을 명시한다 |

## Testing Strategy

- Unit tests: 없음. 문서 작업이라 테스트 코드 추가 대상이 아니다.
- Integration tests: 없음. 대신 TODO 규칙과 번호/링크 정합성을 검증한다.
- Manual verification:
  - `rg --files todos | sort`
  - `git diff --stat`
  - 샘플 TODO 3~5개 열어서 frontmatter/본문 일관성 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| TODO 수가 너무 많아 관리가 어려워짐 | Medium | Medium | index 문서와 target/priority 분리를 제공 |
| surface 누락 | Medium | High | 브레인스토밍 inventory를 source of truth로 사용 |
| 공용 view를 과도하게 분리해 중복 TODO 발생 | Medium | Medium | 파일 기준 surface 우선, context는 본문에 병기 |
| 추후 번호 충돌 | Low | Medium | 현재 최고 번호 확인 후 연속 번호로 생성 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 브레인스토밍 문서에 inventory가 정리되어 있고, TODO 규칙이 명확하며, 이번 작업은 문서 산출물 중심이라 구현 리스크가 낮다.
