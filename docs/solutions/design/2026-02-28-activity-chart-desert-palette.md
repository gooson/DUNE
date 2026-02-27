---
tags: [design-system, chart-colors, desert-palette, activity-category]
date: 2026-02-28
category: solution
status: implemented
---

# Activity Chart Desert Horizon Palette

## Problem

Activity 탭의 차트 색상(도넛, 막대, 링)이 시스템 기본 색상(`.orange`, `.green`, `.blue` 등)을 사용하여 앱의 사막 테마와 불일치.

## Solution

### 1. DS 토큰 + xcassets 패턴

`Assets.xcassets/Colors/Activity*.colorset` 10개 생성 → `DS.Color.activityXxx`로 참조.

| 토큰 | 색상 이름 | 용도 |
|------|----------|------|
| `activityCardio` | Desert Gold | 유산소 (달리기, 걷기, 자전거) |
| `activityStrength` | Copper | 근력 운동 |
| `activityMindBody` | Dusk Lavender | 요가, 필라테스 |
| `activityDance` | Desert Rose | 댄스 |
| `activityCombat` | Terracotta | 격투기 |
| `activitySports` | Dusk Slate | 구기 스포츠 |
| `activityWater` | Oasis Teal | 수영 |
| `activityWinter` | Twilight | 겨울 스포츠 |
| `activityOutdoor` | Desert Sage | 하이킹, 아웃도어 |
| `activityOther` | Warm Stone | 기타 |

### 2. 단일 소스: `ActivityCategory.color`

카테고리→색상 매핑은 `ActivityCategory` extension에 1회만 정의. `WorkoutActivityType.color`, `ExerciseTypeVolume.color`, `ExerciseTypeDetailView.resolveColor()` 모두 `category.color`로 위임.

### 3. 차트 캐시 배열은 `CaseIterable`로 파생

```swift
static let chartColors: [Color] = ActivityCategory.allCases
    .filter { $0 != .multiSport }
    .map(\.color)
```

## Prevention

- 새 `ActivityCategory` case 추가 시 `ActivityCategory.color` switch만 수정하면 전체 앱에 반영
- DS 색상 토큰은 반드시 xcassets 패턴(`Color("Name")`) 사용 — dark mode variant 지원
- `multiSport`는 `cardio`와 동일 색상으로 매핑 (별도 case이므로 switch exhaustiveness 유지)
