---
tags: [navigation, 3d-model, muscle-map, activity-tab, discoverability]
date: 2026-03-15
category: solution
status: implemented
---

# 3D Body Map 네비게이션 바로가기 추가

## Problem

MuscleMap3DView의 진입 경로가 3-4단계 깊이(Train 탭 → Recovery Map → View Details → MuscleMapDetailView → 근육 탭)로, 핵심 기능임에도 발견성(discoverability)이 낮았다.

## Solution

`ActivityDetailDestination` enum에 `.muscleMap3D` case를 추가하고, Recovery Map 섹션의 "View Details" NavigationLink 옆에 compact 아이콘 버튼(`cube` SF Symbol)을 배치하여 1탭으로 MuscleMap3DView에 직접 진입 가능하게 함.

### 변경 파일

| File | Change |
|------|--------|
| `ActivityDetailDestination.swift` | `.muscleMap3D` case 추가 |
| `ActivityView.swift` | `recoveryMapSection()` HStack 재배치 + 3D NavigationLink 추가, `activityDetailView(for:)` routing, `NotificationActivityDestination.id` switch |

### 핵심 패턴

기존 `ActivityDetailDestination` enum 패턴을 그대로 따라 새 네비게이션 대상을 추가하는 표준적인 접근:

1. Enum에 case 추가
2. 모든 exhaustive switch에 case 처리 추가 (컴파일러가 누락 감지)
3. `activityDetailView(for:)` ViewBuilder에서 대상 View로 라우팅

## Prevention

- 새 네비게이션 대상 추가 시 항상 `ActivityDetailDestination` enum 패턴을 따름
- `NotificationActivityDestination.id` switch도 함께 업데이트해야 함 (놓치기 쉬운 부분)

## Lessons Learned

- 3D 기능처럼 시각적으로 임팩트 있는 기능은 진입 경로를 짧게 유지해야 사용률이 높아진다
- 기존 enum 기반 네비게이션 패턴이 잘 정립되어 있어 새 진입점 추가가 매우 간단했다
