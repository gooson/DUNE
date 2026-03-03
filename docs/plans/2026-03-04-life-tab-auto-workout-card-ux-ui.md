---
topic: life-tab-auto-workout-card-ux-ui
date: 2026-03-04
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-04-life-tab-healthkit-auto-achievements.md
  - docs/solutions/architecture/2026-02-28-habit-tab-implementation-patterns.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-life-tab-exercise-auto-achievements.md
---

# Implementation Plan: Life 탭 자동 운동 카드 UX/UI 개선

## Context
현재 Life 탭의 `Auto Workout Achievements`는 항목 수가 많아(9개) 카드가 길게 나열되고, 유사한 목표가 분리되어 루틴 사용자가 "내 루틴이 지켜졌는지"를 한눈에 파악하기 어렵다.  
요구사항은 카드 수를 줄이고(통합 UI), 카드 폭을 정리하며, 루틴 준수 중심의 시각 표현을 강화하는 것이다.

## Requirements

### Functional

- 자동 운동 목표를 유사 성격 기준으로 통합 표시한다.
  - 루틴 빈도(주 5회/7회)
  - 근력 루틴(근력 3회 + 부위별 3회)
  - 러닝 거리(주 15km)
- 기존 규칙 계산 로직(`LifeAutoAchievementService`)은 유지하고, 표시 구조만 재구성한다.
- 루틴 준수 상태(완료 목표 수/전체 목표 수)를 상단에서 즉시 확인 가능해야 한다.
- 데이터가 없는 세부 항목(예: 부위별 0개)은 과도하게 노출하지 않고 숨김/축약한다.

### Non-functional

- 디자인 시스템 컴포넌트(`StandardCard`, `DS.*`)를 그대로 사용한다.
- Life 탭 기존 Habit CRUD/자동 연동 동작 회귀가 없어야 한다.
- iPhone/iPad 모두에서 레이아웃이 과도하게 넓어지지 않도록 폭을 제한한다.

## Approach

UI 계층(`LifeView`)에서 기존 `autoExerciseProgresses`를 통합 섹션 모델로 매핑한다.  
도메인 규칙 엔진은 변경하지 않고, 표시 계층에서 "유사 목표 합치기"와 "데이터 축약"을 처리한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 도메인 서비스에서 통합 DTO 생성 | View 단순화, 테스트 용이 | 도메인 책임 과도 확장, 표시 요구가 도메인에 침투 | 기각 |
| LifeView에서 통합 렌더링 | 영향 범위 작음, 빠른 UX 개선 | View 코드 증가 | 채택 |
| 새 SwiftData 모델로 카드 상태 영속화 | 사용자 커스터마이즈 확장 가능 | 스키마 변경, 과도한 범위 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Life/LifeView.swift` | update | 자동 성취 섹션을 통합 카드 UI로 재구성, 카드 폭/밀도 개선 |
| `DUNETests/LifeAutoAchievementServiceTests.swift` | update | (필요 시) 통합 표시 전제 조건이 되는 규칙 출력 안정성 회귀 보강 |
| `docs/plans/2026-03-04-life-tab-auto-workout-card-ux-ui.md` | add | 구현 계획 문서 |

## Implementation Steps

### Step 1: 통합 표시 모델 정의 (View 내부)

- **Files**: `DUNE/Presentation/Life/LifeView.swift`
- **Changes**:
  - 기존 rule ID를 3개 통합 그룹(루틴/근력/러닝)으로 매핑
  - 완료율/완료 개수 계산 유틸 추가
  - 0값 세부 항목은 조건부 숨김 처리
- **Verification**:
  - auto progress가 존재할 때 3개 카드 이내로 표시되는지 확인
  - 값이 0인 부위 항목이 과다 노출되지 않는지 확인

### Step 2: 카드 UI 리디자인

- **Files**: `DUNE/Presentation/Life/LifeView.swift`
- **Changes**:
  - 상단 루틴 준수 요약(완료 목표 수/전체 목표 수)
  - 섹션별 통합 카드(루틴 빈도, 근력 스플릿, 러닝 거리)
  - iPad에서 최대 폭 제한 + 그리드 배치로 과도한 카드 너비 축소
- **Verification**:
  - iPhone/Regular width에서 시각 균형 확인
  - 기존 테마(`appTheme`)와 충돌 없는지 확인

### Step 3: 테스트/검증

- **Files**: `DUNETests/LifeAutoAchievementServiceTests.swift` (optional)
- **Changes**:
  - 기존 규칙 ID/값이 유지되는지 회귀 검증(필요 시)
- **Verification**:
  - `scripts/test-unit.sh --ios-only --no-regen` 통과

## Edge Cases

| Case | Handling |
|------|----------|
| 자동 성취 데이터가 아예 없음 | 기존 empty state 유지 |
| 일부 규칙만 값 존재 (예: 러닝만 존재) | 해당 섹션만 강조, 나머지 세부값 숨김 |
| 같은 주차에서 목표 수가 많아 텍스트 과밀 | 칩 형태 축약 + 단문 라벨 사용 |
| iPad 폭 과다 확장 | 섹션 컨테이너 `maxWidth` 제한 |

## Testing Strategy

- Unit tests: 기존 `LifeAutoAchievementServiceTests` 회귀 확인
- Integration tests: `LifeViewModelTests`의 autoAchievementCalculation 회귀 확인
- Manual verification: Life 탭에서 카드 수 감소, 루틴 요약 가독성, Habit 기능 회귀 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| View 로직 복잡도 증가 | Medium | Medium | 매핑/렌더링 유틸을 private helper로 분리 |
| 통합 UI에서 기존 정보 누락 체감 | Medium | Medium | 섹션 내 핵심 지표 유지 + 숨김 기준 명확화 |
| 테마별 대비 저하 | Low | Medium | 기존 DS 색상/카드 토큰 재사용 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 도메인 계산 로직을 유지한 채 표시 계층만 조정하므로 회귀 리스크가 낮고, 사용자 요구(통합/가독성)와 직접적으로 맞닿아 있다.
