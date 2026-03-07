---
tags: [activity-tab, hero-card, quick-start, suggested-workout, search, layout]
date: 2026-03-07
category: brainstorm
status: draft
---

# Brainstorm: Activity 탭 Hero-First 레이아웃 재배치

## Problem Statement

현재 Activity 탭은 QuickStart 섹션(검색 + 템플릿 + 인기/최근 운동)이 최상단에 위치하여
히어로 카드(Training Readiness)가 스크롤 아래로 밀려 있다.
앱의 핵심 가치인 "오늘의 컨디션"이 즉시 보이지 않으며, QuickStart 섹션의 가치도 불확실하다.

## Target Users

- 앱을 열고 오늘의 컨디션 상태를 빠르게 확인하려는 사용자
- 추천 운동을 보고 바로 시작하려는 사용자
- 특정 운동을 검색하여 수동으로 기록하려는 사용자

## Success Criteria

1. 앱 진입 시 Hero Card가 즉시 보임 (스크롤 없이)
2. QuickStart 섹션 제거 후에도 운동 검색/시작 경로 유지
3. 추천 운동 섹션에 검색이 자연스럽게 통합
4. 템플릿 접근성 유지 (추천 운동 하단)

## Proposed Layout (변경 후)

```
┌─────────────────────┐
│   READINESS HERO    │  ← 최상단 (CTA 버튼 없음)
│   Score: 78         │
│   HRV | Sleep | Rec │
├─────────────────────┤
│ Recovery Map        │  ← 근육 피로도/볼륨 맵
│ Weekly Stats        │  ← 주간 통계 (iPad: side-by-side)
├─────────────────────┤
│ 🔍 Search exercises │  ← 검색바 (추천 운동 섹션 상단)
│ Suggested Workout   │  ← 추천 운동 카드
│  ├ Bench Press [▶]  │
│  ├ Rows       [▶]  │
│  └ Curls      [▶]  │
│ ┈┈ Templates ┈┈┈┈┈ │  ← 템플릿 스트립 (추천 운동 아래)
├─────────────────────┤
│ Training Volume     │  ← 28일 볼륨 트렌드
├─────────────────────┤
│ Recent Workouts     │
│ Personal Records    │
│ Consistency         │
│ Exercise Mix        │
└─────────────────────┘
```

## 변경 사항 요약

| Before | After |
|--------|-------|
| 1. QuickStart (검색+템플릿+인기/최근) | 1. Hero Card (CTA 없음) |
| 2. Hero Card + Start Workout CTA | 2. Recovery Map + Weekly Stats |
| 3. Recovery Map + Weekly Stats | 3. 검색 + 추천 운동 + 템플릿 |
| 4. Suggested Workout + Training Volume | 4. Training Volume |
| 5. Recent Workouts ... | 5. Recent Workouts ... |

### 제거 항목

- **QuickStart 섹션 전체** (`ActivityQuickStartSection`)
  - 인기 운동 (Popular Exercises) 서브섹션
  - 최근 운동 (Recent Exercises) 서브섹션
  - "All Exercises" 링크
- **Start Workout CTA 버튼** (Hero Card 옆)

### 이동 항목

- **Hero Card** → 최상단 (from position 2)
- **템플릿 스트립** → 추천 운동 아래 (from QuickStart 내부)

### 신규/변경 항목

- **검색바** → 추천 운동 섹션 상단에 통합
  - 검색 시 추천 운동 카드를 검색 결과로 대체 (기존 QuickStart 검색 UX 재활용)

## Constraints

- **기술적**: 검색 로직(custom + library 통합 검색)은 QuickStart ViewModel에 이미 구현되어 있으므로 재활용 가능
- **UX**: "All Exercises" 브라우저 접근 경로가 사라지므로, 검색 결과 내 "Browse All" 링크 필요
- **iPad**: Recovery Map + Weekly Stats의 side-by-side 레이아웃 유지

## Edge Cases

- **검색 중 추천 운동 상태**: 검색 텍스트 입력 시 추천 운동 카드 숨김 → 검색 결과 표시
- **검색 결과 없음**: "No results" + "Browse All Exercises" 링크
- **추천 운동 없음 + 검색 없음**: Rest Day 카드 또는 No Suggestion 카드만 표시
- **템플릿 0개**: 템플릿 스트립 자체 숨김 (기존 동작 유지)
- **데이터 미수집**: Hero Card calibrating 상태 표시 (기존 동작 유지)

## Scope

### MVP (Must-have)

- Hero Card 최상단 이동
- QuickStart 섹션 제거
- Start Workout CTA 제거
- 추천 운동 섹션 상단에 검색바 추가
- 검색 시 추천 운동 대체 표시
- 템플릿 스트립 추천 운동 아래 이동
- "All Exercises" 브라우저 접근 경로 확보

### Nice-to-have (Future)

- 검색 결과에서 바로 운동 시작 (현재는 detail → start)
- 검색 히스토리/자주 검색하는 운동 표시
- 추천 운동 카드 스와이프 인터랙션

## Open Questions

1. "All Exercises" 브라우저를 어디서 접근할 수 있게 할 것인지 (검색 결과 하단? 추천 운동 하단?)
2. iPad에서 검색+추천 운동과 Training Volume의 side-by-side 레이아웃 유지 여부

## Affected Files (예상)

| 파일 | 변경 |
|------|------|
| `ActivityView.swift` | 섹션 순서 재배치, QuickStart 제거, 검색 통합 |
| `ActivityQuickStartSection.swift` | 제거 대상 (검색 로직은 추출) |
| `SuggestedWorkoutSection.swift` | 검색바 추가, 템플릿 스트립 통합 |
| `ActivityViewModel.swift` | QuickStart 관련 state 정리, 검색 state 이동 |
| `TrainingReadinessHeroCard.swift` | CTA 버튼 제거 (또는 별도 파일이면 해당 파일) |

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성
