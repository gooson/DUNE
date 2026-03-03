---
topic: life-tab-ux-improvement
date: 2026-03-04
status: draft
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-04-life-tab-auto-workout-card-ux-ui.md
  - docs/solutions/general/2026-03-03-activity-pull-to-refresh-scrollviewreader-fix.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-life-tab-ux-improvement.md
---

# Implementation Plan: Life 탭 UX 개선

## Context
Life 탭은 기능 자체는 충분하지만, 다른 탭 대비 상위 구조와 섹션 스타일이 다르게 보여 시각적 일관성이 약하다.  
이번 변경의 우선순위는 시각적 일관성이며, iPad 레이아웃 개선과 pull-to-refresh 포함이 요구사항으로 확정되었다.

## Requirements

### Functional

- Life 탭을 `Hero → Section` 중심 구조로 재정렬
- `My Habits`, `Auto Workout Achievements`를 공통 `SectionGroup`으로 통일
- 주기형 습관의 보조 액션(Snooze/Skip/History)을 기본 화면에서 접고 context menu로 이동
- pull-to-refresh 동작 시 Life 화면 계산 상태를 재실행
- iPad에서 섹션 구조를 2열 배치로 개선

### Non-functional

- 기존 Habit CRUD, cycle action, auto achievement 계산 로직 회귀 없음
- SwiftData `@Query` 분리 구조 유지 (부모 재레이아웃 최소화)
- 접근성 식별자(`life-hero-progress`, `life-toolbar-add`) 유지

## Approach

`LifeView`의 루트 스크롤 구조는 유지하면서, `HabitListQueryView` 내부 섹션 구성을 재배치한다.

- Hero는 상단 고정
- 본문은 `SectionGroup` 기반으로 통일
- iPad(`regular`)에서는 `My Habits`와 `Auto Workout Achievements`를 좌우 배치
- pull-to-refresh는 로컬 refresh signal을 통해 기존 계산 루틴(`recalculate`)을 재호출

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 구조 유지 + 스타일만 일부 수정 | 변경량 작음 | 구조 일관성 문제 지속 | 기각 |
| Life 전용 새 카드/섹션 컴포넌트 추가 | Life 특화 가능 | 공통성 저하, 유지보수 비용 증가 | 기각 |
| `SectionGroup` 중심으로 재정렬 + context menu 단순화 | 탭 간 일관성 높음, UX 밀도 개선 | 초기 리팩토링 범위 증가 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Life/LifeView.swift` | update | 섹션 구조 통일, iPad 2열, context menu 정리, pull-to-refresh 신호 연결 |
| `docs/brainstorms/2026-03-04-life-tab-ux-improvement.md` | add | 요구사항 정리 문서 |

## Implementation Steps

### Step 1: 상위 구조 및 섹션 패턴 통일

- **Files**: `DUNE/Presentation/Life/LifeView.swift`
- **Changes**:
  - Hero를 상단 유지
  - `My Habits`, `Auto Workout Achievements`를 `SectionGroup`으로 래핑
  - iPad에서 2열 배치 적용
- **Verification**:
  - iPhone/iPad에서 섹션 헤더/카드 스타일 일관성 확인
  - Hero 접근성 식별자 유지 확인

### Step 2: 보조 액션 단순화

- **Files**: `DUNE/Presentation/Life/LifeView.swift`
- **Changes**:
  - 주기형 보조 버튼 노출 제거
  - Edit/Archive/Snooze/Skip/History를 context menu로 통합
- **Verification**:
  - cycle habit에서 각 보조 액션 동작/비활성 조건 확인

### Step 3: Pull-to-Refresh 연동

- **Files**: `DUNE/Presentation/Life/LifeView.swift`
- **Changes**:
  - `waveRefreshable` 추가
  - refresh signal 변경 시 `recalculate()` 실행
- **Verification**:
  - 당겨서 새로고침 시 진행률/자동 달성 정보가 갱신되는지 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 습관 0개 상태 | `My Habits` 섹션에서 EmptyState + Add CTA 표시 |
| cycle habit not due 상태 | context menu에서 Snooze/Skip 비활성화 |
| 자동 달성 데이터 없음 | 자동 섹션에 no-data card 표시 |
| 외부 refresh signal + 수동 pull-to-refresh 동시 발생 | signal 합산 방식으로 동일 재계산 루틴 실행 |

## Testing Strategy

- Unit tests: 로직 변경 없음(뷰 구조 재배치 중심), 기존 Life 관련 테스트 회귀 확인
- Integration tests: 기존 Life 뷰 동작(편집/보관/cycle action/히스토리) 수동 확인
- Manual verification: iPhone/iPad 레이아웃, context menu 액션, pull-to-refresh 동작 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 섹션 재배치 후 정보 우선순위 혼선 | Low | Medium | Hero 고정 + 섹션 제목 명확화 |
| context menu로 액션 이동 시 발견성 저하 | Medium | Medium | 핵심 액션은 행 본문 유지, 보조 액션만 이동 |
| refresh signal 연결 누락으로 갱신 실패 | Low | Medium | `onChange(refreshSignal)` + 수동 새로고침 둘 다 연결 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 공통 컴포넌트 재사용 중심의 구조 개선으로 리스크가 낮고, 기존 데이터/도메인 로직을 변경하지 않아 회귀 가능성이 제한적이다.
