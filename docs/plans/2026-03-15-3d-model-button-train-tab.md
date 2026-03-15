---
topic: 3D Body Map 버튼 — Train 탭 Recovery Map 진입점
date: 2026-03-15
status: draft
confidence: high
related_solutions:
  - architecture/2026-02-23-activity-detail-navigation-pattern.md
  - architecture/2026-02-27-muscle-map-detail-view-integration.md
related_brainstorms:
  - 2026-03-15-3d-model-button-on-train-tab.md
---

# Implementation Plan: 3D Body Map 버튼 — Train 탭 Recovery Map 진입점

## Context

3D Body Map(`MuscleMap3DView`)의 현재 진입 경로가 3-4단계 깊이(Train → Recovery Map → View Details → MuscleMapDetailView → 근육 탭)로 발견성이 낮다. Recovery Map 섹션에 compact 아이콘 버튼을 추가하여 1탭으로 3D 뷰에 직접 접근 가능하게 한다.

## Requirements

### Functional

- Train 탭 Recovery Map 섹션의 "View Details" 옆에 3D 아이콘 버튼 배치
- 버튼 탭 시 MuscleMap3DView로 직접 네비게이션 (Recovery 모드)
- 기존 "View Details" → MuscleMapDetailView 경로는 유지

### Non-functional

- 기존 Recovery Map 섹션 레이아웃 일관성 유지
- SF Symbol compact 스타일로 기존 UI를 압도하지 않음

## Approach

`ActivityDetailDestination` enum에 `.muscleMap3D` case를 추가하고, `recoveryMapSection()`의 하단 네비게이션 영역에 3D 아이콘 버튼을 "View Details" 옆에 배치한다. `activityDetailView(for:)` switch에서 `.muscleMap3D`를 `MuscleMap3DView`로 라우팅한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| A: NavigationLink + 새 enum case | 기존 패턴과 일치, type-safe | enum case 추가 필요 | **채택** |
| B: sheet로 3D 뷰 표시 | 네비게이션 독립적 | 기존 push 패턴과 불일치, dismiss UX 다름 | 기각 |
| C: 기존 muscleMap case 재활용 + 파라미터 | case 추가 없음 | MuscleMapDetailView vs 3DView 분기 복잡 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Activity/ActivityDetailDestination.swift` | Modify | `.muscleMap3D` case 추가 |
| `DUNE/Presentation/Activity/ActivityView.swift` | Modify | `recoveryMapSection()`에 3D 버튼 추가, `activityDetailView(for:)`에 routing 추가, `NotificationActivityDestination.id`에 case 추가 |

## Implementation Steps

### Step 1: ActivityDetailDestination에 muscleMap3D case 추가

- **Files**: `ActivityDetailDestination.swift`
- **Changes**: `case muscleMap3D` 추가
- **Verification**: 컴파일러가 exhaustive switch 누락을 잡아줌

### Step 2: ActivityView — routing과 UI 추가

- **Files**: `ActivityView.swift`
- **Changes**:
  1. `NotificationActivityDestination.id` switch에 `.muscleMap3D` case 추가
  2. `activityDetailView(for:)` switch에 `.muscleMap3D` → `MuscleMap3DView(fatigueStates:highlightedMuscle:)` 추가
  3. `recoveryMapSection()`의 NavigationLink 옆에 3D 아이콘 NavigationLink 추가
- **Verification**: Train 탭에서 3D 버튼이 표시되고 탭 시 MuscleMap3DView로 이동

## Edge Cases

| Case | Handling |
|------|----------|
| fatigueStates가 빈 경우 | MuscleMap3DView는 빈 데이터에서도 정상 렌더링 (기존 처리) |
| USDZ 로드 실패 | MuscleMap3DScene에서 이미 에러 처리 (기존 처리) |

## Testing Strategy

- Unit tests: 테스트 면제 (SwiftUI View body 변경, enum case 추가만)
- Manual verification: Train 탭 → 3D 버튼 탭 → MuscleMap3DView 진입 확인
- Build: `scripts/build-ios.sh` 통과

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 레이아웃 깨짐 | Low | Low | "View Details"와 동일한 HStack 패턴 사용 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 ActivityDetailDestination 패턴을 그대로 따르는 단순한 enum case 추가 + NavigationLink 추가. 영향 범위가 2개 파일로 한정됨.
